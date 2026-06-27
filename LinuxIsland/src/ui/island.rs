//! The island widget: a collapsed pill that grows into the expanded card.
//!
//! Holds now-playing (cover/title/artist + transport + shuffle/repeat + progress
//! seek), a battery readout, a volume slider, a notification banner, a screenshot
//! preview, and the file shelf. Services push state in via the `set_*` / `show_*`
//! methods. The collapsed ↔ expanded transition toggles the `expanded` CSS class.

use std::cell::{Cell, RefCell};
use std::path::PathBuf;
use std::rc::Rc;

use gtk::gdk;
use gtk::glib;
use gtk::glib::clone;
use gtk::prelude::*;

use crate::interaction::{self, Handlers};
use crate::model::{AppState, Battery, Notification, Track};
use crate::services::mpris::Controls;
use crate::pomodoro::Pomodoro;
use crate::services::hud::HudKind;
use crate::services::{screenshots, volume};
use crate::settings::{InteractionMode, Settings};
use crate::shelf::ShelfStore;
use crate::ui::clipboard::ClipboardView;
use crate::ui::gmail::GmailView;
use crate::ui::settings_window;
use crate::ui::shelf::ShelfView;
use crate::ui::windows::WindowsView;

#[derive(Clone)]
pub struct IslandView {
    pub root: gtk::Box,
    cover: gtk::Image,
    title: gtk::Label,
    artist: gtk::Label,
    play_btn: gtk::Button,
    shuffle_btn: gtk::Button,
    repeat_btn: gtk::Button,
    progress: gtk::Scale,
    progress_guard: Rc<Cell<bool>>,
    battery: gtk::Label,
    volume_scale: gtk::Scale,
    volume_guard: Rc<Cell<bool>>,
    banner: gtk::Label,
    shot_box: gtk::Box,
    shot_image: gtk::Image,
    shot_path: Rc<RefCell<Option<String>>>,
    last_track: Rc<RefCell<Option<Track>>>,
    shelf: ShelfView,
    pub clipboard: ClipboardView,
    pub gmail: GmailView,
    pub windows: WindowsView,
    top_row: gtk::Box,
    hud_box: gtk::Box,
    hud_icon: gtk::Image,
    hud_bar: gtk::LevelBar,
    weather_box: gtk::Box,
    weather_icon: gtk::Image,
    weather_label: gtk::Label,
}

impl IslandView {
    pub fn set_track(&self, track: Option<&Track>) {
        *self.last_track.borrow_mut() = track.cloned();
        match track {
            Some(t) => {
                self.title.set_text(if t.title.is_empty() { "—" } else { &t.title });
                self.artist.set_text(&t.artist);
                self.play_btn.set_icon_name(play_icon(t.playing));
                set_cover(&self.cover, t.art_url.as_deref());
                set_active(&self.shuffle_btn, t.shuffle);
                set_active(&self.repeat_btn, t.loop_status != "None" && !t.loop_status.is_empty());
                self.progress.set_range(0.0, (t.length_us.max(1)) as f64);
            }
            None => {
                self.title.set_text("LinuxIsland");
                self.artist.set_text("Çalan parça yok");
                self.play_btn.set_icon_name(play_icon(false));
                self.cover.set_icon_name(Some("audio-x-generic-symbolic"));
                set_active(&self.shuffle_btn, false);
                set_active(&self.repeat_btn, false);
            }
        }
    }

    /// Reflect playback progress (position µs, length µs) onto the seek bar.
    pub fn set_progress(&self, position_us: i64, length_us: i64) {
        if length_us <= 0 {
            return;
        }
        self.progress_guard.set(true);
        self.progress.set_range(0.0, length_us as f64);
        self.progress.set_value(position_us.clamp(0, length_us) as f64);
        self.progress_guard.set(false);
    }

    pub fn set_battery(&self, battery: Option<Battery>) {
        match battery {
            Some(b) => {
                let bolt = if b.charging { "⚡" } else { "" };
                self.battery.set_text(&format!("{bolt}{}%", b.percentage));
                self.battery.set_visible(true);
            }
            None => self.battery.set_visible(false),
        }
    }

    pub fn set_volume(&self, fraction: f64) {
        self.volume_guard.set(true);
        self.volume_scale.set_value(fraction.clamp(0.0, 1.0));
        self.volume_guard.set(false);
    }

    pub fn set_notification(&self, note: Option<&Notification>) {
        match note {
            Some(n) => {
                let text = if n.body.is_empty() {
                    format!("{}: {}", n.app, n.summary)
                } else {
                    format!("{}: {} — {}", n.app, n.summary, n.body)
                };
                self.banner.set_text(&text);
                self.banner.set_visible(true);
            }
            None => self.banner.set_visible(false),
        }
    }

    pub fn show_screenshot(&self, path: &str) {
        *self.shot_path.borrow_mut() = Some(path.to_owned());
        self.shot_image.set_from_file(Some(path));
        self.shot_box.set_visible(true);
    }

    pub fn hide_screenshot(&self) {
        *self.shot_path.borrow_mut() = None;
        self.shot_box.set_visible(false);
    }

    /// Show the brightness/volume HUD (replacing the top row briefly).
    pub fn show_hud(&self, kind: HudKind, level: f64) {
        self.hud_icon.set_icon_name(Some(match kind {
            HudKind::Brightness => "display-brightness-symbolic",
            HudKind::Volume => if level <= 0.001 {
                "audio-volume-muted-symbolic"
            } else {
                "audio-volume-high-symbolic"
            },
        }));
        self.hud_bar.set_value(level.clamp(0.0, 1.0));
        self.top_row.set_visible(false);
        self.hud_box.set_visible(true);
    }

    pub fn hide_hud(&self) {
        self.hud_box.set_visible(false);
        self.top_row.set_visible(true);
    }

    pub fn set_weather(&self, code: i32, city: &str, temp_c: i32) {
        self.weather_icon.set_icon_name(Some(crate::services::weather::icon_name(code)));
        self.weather_label.set_text(&format!("{city} · {temp_c}°"));
        self.weather_box.set_visible(true);
    }
}

pub fn build(
    state: Rc<RefCell<AppState>>,
    controls: Controls,
    settings: Rc<RefCell<Settings>>,
    shelf_store: Rc<RefCell<ShelfStore>>,
) -> IslandView {
    let cfg = settings.borrow().clone();

    let root = gtk::Box::new(gtk::Orientation::Vertical, 6);
    root.add_css_class("island");
    root.set_halign(gtk::Align::Center);
    root.set_valign(gtk::Align::Start);

    // --- Brightness/volume HUD (transient; replaces the top row briefly) ---
    let hud_box = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    hud_box.add_css_class("hud");
    hud_box.set_visible(false);
    let hud_icon = gtk::Image::from_icon_name("display-brightness-symbolic");
    let hud_bar = gtk::LevelBar::new();
    hud_bar.set_min_value(0.0);
    hud_bar.set_max_value(1.0);
    hud_bar.set_hexpand(true);
    hud_box.append(&hud_icon);
    hud_box.append(&hud_bar);
    root.append(&hud_box);

    // --- Weather row (idle widget) ---
    let weather_box = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    weather_box.add_css_class("controls");
    weather_box.set_halign(gtk::Align::Center);
    weather_box.set_visible(false);
    let weather_icon = gtk::Image::from_icon_name("weather-overcast-symbolic");
    let weather_label = gtk::Label::new(None);
    weather_label.add_css_class("subtitle");
    weather_box.append(&weather_icon);
    weather_box.append(&weather_label);
    root.append(&weather_box);

    // --- Top row: cover + title/artist + battery ---
    let top = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    let cover = gtk::Image::from_icon_name("audio-x-generic-symbolic");
    cover.set_pixel_size(40);
    cover.add_css_class("cover");
    top.append(&cover);

    let text_col = gtk::Box::new(gtk::Orientation::Vertical, 1);
    let title = label("LinuxIsland", "title");
    let artist = label("Çalan parça yok", "subtitle");
    text_col.append(&title);
    text_col.append(&artist);
    text_col.set_hexpand(true);
    top.append(&text_col);

    let battery = label("", "battery");
    battery.set_visible(false);
    top.append(&battery);
    root.append(&top);

    // --- Notification banner ---
    let banner = label("", "banner");
    banner.set_visible(false);
    banner.set_wrap(true);
    root.append(&banner);

    // --- Progress / seek bar ---
    let progress = gtk::Scale::with_range(gtk::Orientation::Horizontal, 0.0, 1.0, 1000.0);
    progress.add_css_class("controls");
    progress.set_hexpand(true);
    progress.set_draw_value(false);
    let progress_guard = Rc::new(Cell::new(false));
    root.append(&progress);

    // --- Transport row: shuffle | prev | play | next | repeat ---
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    row.add_css_class("controls");
    row.set_halign(gtk::Align::Center);
    let shuffle_btn = transport_button("media-playlist-shuffle-symbolic");
    let prev_btn = transport_button("media-skip-backward-symbolic");
    let play_btn = transport_button("media-playback-start-symbolic");
    let next_btn = transport_button("media-skip-forward-symbolic");
    let repeat_btn = transport_button("media-playlist-repeat-symbolic");
    for b in [&shuffle_btn, &prev_btn, &play_btn, &next_btn, &repeat_btn] {
        row.append(b);
    }
    root.append(&row);

    prev_btn.connect_clicked(clone!(@strong controls => move |_| controls.previous()));
    play_btn.connect_clicked(clone!(@strong controls => move |_| controls.play_pause()));
    next_btn.connect_clicked(clone!(@strong controls => move |_| controls.next()));
    shuffle_btn.connect_clicked(clone!(@strong controls => move |_| controls.toggle_shuffle()));
    repeat_btn.connect_clicked(clone!(@strong controls => move |_| controls.cycle_loop()));

    // --- Volume slider ---
    let volume_scale = gtk::Scale::with_range(gtk::Orientation::Horizontal, 0.0, 1.0, 0.01);
    volume_scale.add_css_class("controls");
    volume_scale.set_hexpand(true);
    volume_scale.set_visible(cfg.show_volume);
    let volume_guard = Rc::new(Cell::new(false));
    volume_scale.connect_value_changed(clone!(@strong volume_guard => move |s| {
        if !volume_guard.get() { volume::set(s.value()); }
    }));
    root.append(&volume_scale);

    // --- Screenshot preview ---
    let shot_box = gtk::Box::new(gtk::Orientation::Vertical, 6);
    shot_box.add_css_class("controls");
    shot_box.set_visible(false);
    let shot_image = gtk::Image::new();
    shot_image.set_pixel_size(120);
    shot_box.append(&shot_image);
    let shot_path: Rc<RefCell<Option<String>>> = Rc::new(RefCell::new(None));

    let shot_actions = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    shot_actions.set_halign(gtk::Align::Center);
    let copy_btn = transport_button("edit-copy-symbolic");
    let open_btn = transport_button("folder-symbolic");
    let del_btn = transport_button("user-trash-symbolic");
    shot_actions.append(&copy_btn);
    shot_actions.append(&open_btn);
    shot_actions.append(&del_btn);
    shot_box.append(&shot_actions);
    root.append(&shot_box);

    // --- Pomodoro widget (idle productivity timer) ---
    let pomo = Pomodoro::new();
    let pomo_box = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    pomo_box.add_css_class("controls");
    pomo_box.set_halign(gtk::Align::Center);
    let pomo_icon = gtk::Image::from_icon_name("alarm-symbolic");
    let pomo_label = gtk::Label::new(Some("25:00"));
    pomo_label.add_css_class("pomodoro");
    let pomo_play = transport_button("media-playback-start-symbolic");
    let pomo_reset = transport_button("view-refresh-symbolic");
    pomo_box.append(&pomo_icon);
    pomo_box.append(&pomo_label);
    pomo_box.append(&pomo_play);
    pomo_box.append(&pomo_reset);
    root.append(&pomo_box);

    pomo.on_change(clone!(@strong pomo_label, @strong pomo_play => move |rem, running| {
        pomo_label.set_text(&format!("{:02}:{:02}", rem / 60, rem % 60));
        pomo_play.set_icon_name(play_icon(running));
    }));
    pomo_play.connect_clicked(clone!(@strong pomo => move |_| pomo.toggle()));
    pomo_reset.connect_clicked(clone!(@strong pomo => move |_| pomo.reset()));

    // --- Windows + Gmail + clipboard strips ---
    let windows = WindowsView::build();
    root.append(&windows.container);
    let gmail = GmailView::build();
    root.append(&gmail.container);
    let clipboard = ClipboardView::build();
    root.append(&clipboard.container);

    // --- File shelf ---
    let shelf = ShelfView::build(shelf_store);
    root.append(&shelf.container);

    let view = IslandView {
        root: root.clone(),
        cover: cover.clone(),
        title,
        artist,
        play_btn,
        shuffle_btn,
        repeat_btn,
        progress: progress.clone(),
        progress_guard,
        battery,
        volume_scale,
        volume_guard,
        banner,
        shot_box: shot_box.clone(),
        shot_image,
        shot_path: shot_path.clone(),
        last_track: Rc::new(RefCell::new(None)),
        shelf: shelf.clone(),
        clipboard: clipboard.clone(),
        gmail: gmail.clone(),
        windows: windows.clone(),
        top_row: top.clone(),
        hud_box: hud_box.clone(),
        hud_icon: hud_icon.clone(),
        hud_bar: hud_bar.clone(),
        weather_box: weather_box.clone(),
        weather_icon: weather_icon.clone(),
        weather_label: weather_label.clone(),
    };

    // Seek: dragging the progress bar issues SetPosition for the current track.
    progress.connect_value_changed(clone!(@strong view, @strong controls => move |s| {
        if view.progress_guard.get() { return; }
        if let Some(t) = view.last_track.borrow().as_ref() {
            if !t.track_id.is_empty() {
                controls.set_position(t.track_id.clone(), s.value() as i64);
            }
        }
    }));

    // Cover click → raise the player.
    let cover_click = gtk::GestureClick::new();
    cover_click.connect_pressed(clone!(@strong controls => move |_, _, _, _| controls.raise()));
    cover.add_controller(cover_click);

    // Screenshot actions.
    copy_btn.connect_clicked(clone!(@strong shot_path => move |_| {
        if let Some(p) = shot_path.borrow().as_deref() { screenshots::actions::copy(p); }
    }));
    open_btn.connect_clicked(clone!(@strong shot_path => move |_| {
        if let Some(p) = shot_path.borrow().as_deref() { screenshots::actions::reveal(p); }
    }));
    del_btn.connect_clicked(clone!(@strong view => move |_| {
        if let Some(p) = view.shot_path.borrow().as_deref() { screenshots::actions::delete(p); }
        view.hide_screenshot();
    }));

    // Drop files anywhere on the island → add to the shelf.
    let drop = gtk::DropTarget::new(gdk::FileList::static_type(), gdk::DragAction::COPY);
    drop.connect_drop(clone!(@strong shelf => move |_, value, _, _| {
        if let Ok(list) = value.get::<gdk::FileList>() {
            let paths: Vec<PathBuf> = list.files().into_iter().filter_map(|f| f.path()).collect();
            if !paths.is_empty() { shelf.add_paths(paths); return true; }
        }
        false
    }));
    root.add_controller(drop);

    // Right-click → settings window.
    let menu = gtk::GestureClick::new();
    menu.set_button(gdk::BUTTON_SECONDARY);
    menu.connect_pressed(clone!(@strong settings => move |_, _, _, _| {
        settings_window::show(settings.clone());
    }));
    root.add_controller(menu);

    let handlers = Handlers {
        on_expand: Box::new(clone!(@weak root, @strong state => move || {
            state.borrow_mut().expanded = true;
            root.add_css_class("expanded");
        })),
        on_collapse: Box::new(clone!(@weak root, @strong state => move || {
            state.borrow_mut().expanded = false;
            root.remove_css_class("expanded");
        })),
        on_next: Box::new(clone!(@strong controls => move || controls.next())),
        on_previous: Box::new(clone!(@strong controls => move || controls.previous())),
    };
    let click_mode = cfg.interaction_mode == InteractionMode::Click;
    let timing = interaction::HoverTiming {
        open_ms: cfg.hover_sensitivity.open_ms(),
        close_ms: cfg.hover_sensitivity.close_ms(),
    };
    interaction::attach(&root, handlers, click_mode, timing);

    view
}

fn play_icon(playing: bool) -> &'static str {
    if playing { "media-playback-pause-symbolic" } else { "media-playback-start-symbolic" }
}

fn set_active(btn: &gtk::Button, active: bool) {
    if active { btn.add_css_class("active"); } else { btn.remove_css_class("active"); }
}

fn set_cover(cover: &gtk::Image, art_url: Option<&str>) {
    match art_url.and_then(file_path) {
        Some(path) => cover.set_from_file(Some(&path)),
        None => cover.set_icon_name(Some("audio-x-generic-symbolic")),
    }
}

fn file_path(url: &str) -> Option<String> {
    if let Some(rest) = url.strip_prefix("file://") {
        Some(rest.to_owned())
    } else if url.starts_with('/') {
        Some(url.to_owned())
    } else {
        None
    }
}

fn label(text: &str, class: &str) -> gtk::Label {
    let l = gtk::Label::new(Some(text));
    l.add_css_class(class);
    l.set_ellipsize(gtk::pango::EllipsizeMode::End);
    l.set_xalign(0.0);
    l
}

fn transport_button(icon: &str) -> gtk::Button {
    let btn = gtk::Button::from_icon_name(icon);
    btn.add_css_class("flat");
    btn.add_css_class("transport");
    btn
}
