//! LinuxIsland — top-center always-on-top island for Wayland (wlroots).
//!
//! Mirror of the macOS app's layering:
//!   model        → shared state + transient content models
//!   settings     → persisted user settings (TOML)
//!   geometry     → logical sizes + the drag offset (a layer-shell margin here)
//!   interaction  → hover/click/swipe controllers
//!   services     → MPRIS / battery / volume / screenshots / notifications
//!   ui::island   → the widget tree
//!   main         → orchestration: window + layer-shell + service wiring

mod autostart;
mod geometry;
mod interaction;
mod model;
mod pomodoro;
mod services;
mod settings;
mod shelf;
mod ui;

use std::cell::{Cell, RefCell};
use std::rc::Rc;
use std::time::Duration;

use gtk::gdk;
use gtk::glib;
use gtk::glib::clone;
use gtk::prelude::*;
use gtk::{Application, ApplicationWindow};
use gtk4_layer_shell::{Edge, KeyboardMode, Layer, LayerShell};

use model::{AppState, Notification};
use settings::{BatteryMode, Settings};
use ui::island::IslandView;

const APP_ID: &str = "io.github.linuxisland";
/// Warn once when the battery first drops to/below this while discharging.
const LOW_BATTERY: u8 = 20;

fn main() -> glib::ExitCode {
    let app = Application::builder().application_id(APP_ID).build();
    app.connect_startup(|_| load_css());
    app.connect_activate(build_ui);
    app.run()
}

fn load_css() {
    let provider = gtk::CssProvider::new();
    provider.load_from_string(include_str!("../data/style.css"));
    if let Some(display) = gdk::Display::default() {
        gtk::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}

fn build_ui(app: &Application) {
    let settings = Rc::new(RefCell::new(Settings::load()));
    let state = Rc::new(RefCell::new(AppState::default()));

    let window = ApplicationWindow::builder()
        .application(app)
        .resizable(false)
        .decorated(false)
        .build();

    // --- wlr-layer-shell: top overlay that doesn't reserve space ---
    window.init_layer_shell();
    window.set_layer(Layer::Overlay);
    window.set_namespace("linux-island");
    window.set_anchor(Edge::Top, true);
    window.set_exclusive_zone(0);
    window.set_keyboard_mode(KeyboardMode::None);
    window.add_css_class("island-window");
    // When movable is first enabled, seed a roughly-centered horizontal offset so
    // anchoring Left doesn't snap the island to the top-left corner.
    {
        let mut s = settings.borrow_mut();
        if s.movable && s.offset_x == 0 && s.offset_y == 0 {
            s.offset_x = ((primary_monitor_width() - geometry::COLLAPSED_WIDTH) / 2).max(0);
            s.save();
        }
    }
    apply_offset(&window, &settings.borrow());

    // --- Build the island ---
    let shelf_store = Rc::new(RefCell::new(shelf::ShelfStore::load()));
    let (controls, commands) = services::mpris::channel();
    let view = ui::island::build(state.clone(), controls, settings.clone(), shelf_store);
    window.set_child(Some(&view.root));
    window.present();

    if settings.borrow().movable {
        attach_drag(&window, &view.root, settings.clone());
    }

    start_services(&view, &settings, commands);
}

/// Apply the saved drag offset as layer-shell margins. When movable, anchor Left
/// too so `offset_x` becomes an absolute horizontal position (seeded to center on
/// first enable); otherwise the island stays compositor-centered.
fn apply_offset(window: &ApplicationWindow, settings: &Settings) {
    window.set_margin(Edge::Top, geometry::BASE_TOP_MARGIN + settings.offset_y);
    if settings.movable {
        window.set_anchor(Edge::Left, true);
        window.set_margin(Edge::Left, settings.offset_x.max(0));
    }
}

/// Width of the primary monitor in logical px (fallback 1920).
fn primary_monitor_width() -> i32 {
    gdk::Display::default()
        .and_then(|d| d.monitors().item(0))
        .and_downcast::<gdk::Monitor>()
        .map(|m| m.geometry().width())
        .unwrap_or(1920)
}

/// Drag-to-move: update the layer-shell margins live and persist on release.
fn attach_drag(window: &ApplicationWindow, root: &gtk::Box, settings: Rc<RefCell<Settings>>) {
    let drag = gtk::GestureDrag::new();
    let start = Rc::new(Cell::new((0i32, 0i32)));

    drag.connect_drag_begin(clone!(@strong settings, @strong start => move |_, _, _| {
        let s = settings.borrow();
        start.set((s.offset_x, s.offset_y));
    }));
    drag.connect_drag_update(clone!(@weak window, @strong settings, @strong start => move |_, dx, dy| {
        let (sx, sy) = start.get();
        let mut s = settings.borrow_mut();
        s.offset_x = (sx + dx as i32).max(0);
        s.offset_y = (sy + dy as i32).max(0);
        apply_offset(&window, &s);
    }));
    drag.connect_drag_end(clone!(@strong settings => move |_, _, _| {
        settings.borrow().save();
    }));
    root.add_controller(drag);
}

fn start_services(
    view: &IslandView,
    settings: &Rc<RefCell<Settings>>,
    commands: async_channel::Receiver<services::mpris::Command>,
) {
    // Now playing (MPRIS): track changes + progress polling.
    if settings.borrow().show_music {
        let v = view.clone();
        let vp = view.clone();
        services::mpris::start(
            commands,
            move |track| v.set_track(track.as_ref()),
            move |(pos, len)| vp.set_progress(pos, len),
        );
    }

    // Battery (sysfs poll) + low-battery warning once on crossing below threshold.
    let battery_mode = settings.borrow().battery_mode;
    if battery_mode != BatteryMode::Off {
        let v = view.clone();
        let last = Rc::new(Cell::new(101u8));
        let warn_token = Rc::new(Cell::new(0u64));
        services::battery::start(move |b| {
            v.set_battery(b);
            let Some(b) = b else { return };
            let prev = last.replace(b.percentage);
            if !b.charging && prev > LOW_BATTERY && b.percentage <= LOW_BATTERY {
                v.set_notification(Some(&Notification {
                    app: "🔋 Pil".into(),
                    summary: format!("Düşük pil — %{}", b.percentage),
                    body: String::new(),
                }));
                let id = warn_token.get().wrapping_add(1);
                warn_token.set(id);
                let (v2, token2) = (v.clone(), warn_token.clone());
                glib::timeout_add_local_once(Duration::from_secs(5), move || {
                    if token2.get() == id {
                        v2.set_notification(None);
                    }
                });
            }
        });
    }

    // Volume (wpctl): seed the slider, then it drives wpctl on change.
    if let Some(vol) = services::volume::get() {
        view.set_volume(vol);
    }

    // Notification banner (auto-clears after 5s; a token avoids a stale clear).
    if settings.borrow().show_notifications {
        let v = view.clone();
        let token = Rc::new(Cell::new(0u64));
        services::notifications::start(move |note| {
            v.set_notification(Some(&note));
            let id = token.get().wrapping_add(1);
            token.set(id);
            let v2 = v.clone();
            let token2 = token.clone();
            glib::timeout_add_local_once(Duration::from_secs(5), move || {
                if token2.get() == id {
                    v2.set_notification(None);
                }
            });
        });
    }

    // Screenshot preview (auto-clears after 6s).
    {
        let v = view.clone();
        let token = Rc::new(Cell::new(0u64));
        services::screenshots::start(move |path| {
            v.show_screenshot(&path);
            let id = token.get().wrapping_add(1);
            token.set(id);
            let v2 = v.clone();
            let token2 = token.clone();
            glib::timeout_add_local_once(Duration::from_secs(6), move || {
                if token2.get() == id {
                    v2.hide_screenshot();
                }
            });
        });
    }

    // Clipboard history.
    {
        let v = view.clone();
        services::clipboard::start(move |items| v.clipboard.set_items(items));
    }

    // Brightness/volume HUD.
    {
        let v = view.clone();
        let token = Rc::new(Cell::new(0u64));
        services::hud::start(move |kind, level| {
            v.show_hud(kind, level);
            let id = token.get().wrapping_add(1);
            token.set(id);
            let (v2, t2) = (v.clone(), token.clone());
            glib::timeout_add_local_once(Duration::from_millis(1300), move || {
                if t2.get() == id {
                    v2.hide_hud();
                }
            });
        });
    }

    // Device/volume event flashes.
    {
        let flash = banner_flasher(view.clone(), 4);
        services::devices::start(move |title, name| {
            flash(Notification { app: format!("🔌 {title}"), summary: name, body: String::new() });
        });
    }

    // Gmail (reads on next launch after connecting in settings).
    if settings.borrow().gmail_connected() {
        if let (Some(email), Some(pass)) =
            (settings.borrow().gmail_email.clone(), Settings::gmail_password())
        {
            let v = view.clone();
            let flash = banner_flasher(view.clone(), 5);
            services::gmail::start(email, pass, move |update| {
                v.gmail.set(update.unread, update.messages);
                for m in update.new {
                    flash(Notification { app: "📧 Gmail".into(), summary: m.author, body: m.title });
                }
            });
        }
    }
}

/// Returns a closure that shows a transient banner for `secs`, superseding the
/// previous one via a token (so a stale clear can't hide a newer banner).
fn banner_flasher(view: IslandView, secs: u64) -> impl Fn(Notification) {
    let token = Rc::new(Cell::new(0u64));
    move |note: Notification| {
        view.set_notification(Some(&note));
        let id = token.get().wrapping_add(1);
        token.set(id);
        let (v2, t2) = (view.clone(), token.clone());
        glib::timeout_add_local_once(Duration::from_secs(secs), move || {
            if t2.get() == id {
                v2.set_notification(None);
            }
        });
    }
}
