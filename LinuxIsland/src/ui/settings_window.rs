//! Settings window — Linux equivalent of the macOS `SettingsView`.
//!
//! Opened by right-clicking the island. Edits are written to the TOML config
//! immediately; layer-shell-affecting options (movable, interaction mode) take
//! full effect on the next launch.

use std::cell::RefCell;
use std::rc::Rc;

use gtk::glib::clone;
use gtk::prelude::*;

use crate::settings::{BatteryMode, InteractionMode, Settings};

pub fn show(settings: Rc<RefCell<Settings>>) {
    let win = gtk::Window::builder()
        .title("LinuxIsland Ayarları")
        .default_width(360)
        .default_height(360)
        .build();

    let root = gtk::Box::new(gtk::Orientation::Vertical, 12);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(18);
    root.set_margin_end(18);

    root.append(&heading("Özellikler"));

    let s = settings.borrow().clone();

    root.append(&switch_row("Müzik göstergesi", s.show_music, clone!(@strong settings => move |on| {
        settings.borrow_mut().show_music = on; settings.borrow().save();
    })));
    root.append(&switch_row("Bildirim banner'ı", s.show_notifications, clone!(@strong settings => move |on| {
        settings.borrow_mut().show_notifications = on; settings.borrow().save();
    })));
    root.append(&switch_row("Ses kaydırıcısı", s.show_volume, clone!(@strong settings => move |on| {
        settings.borrow_mut().show_volume = on; settings.borrow().save();
    })));
    root.append(&switch_row("Tıkla ile aç (kapalı = hover)", s.interaction_mode == InteractionMode::Click,
        clone!(@strong settings => move |on| {
            settings.borrow_mut().interaction_mode = if on { InteractionMode::Click } else { InteractionMode::Hover };
            settings.borrow().save();
        })));
    root.append(&switch_row("Taşınabilir ada", s.movable, clone!(@strong settings => move |on| {
        settings.borrow_mut().movable = on; settings.borrow().save();
    })));
    // Autostart is backed by the .desktop file (its own source of truth).
    root.append(&switch_row("Açılışta başlat", crate::autostart::is_enabled(), |on| {
        crate::autostart::set(on);
    }));

    // Battery mode dropdown.
    let battery_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    battery_row.append(&gtk::Label::new(Some("Pil göstergesi")));
    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    battery_row.append(&spacer);
    let dd = gtk::DropDown::from_strings(&["Kapalı", "Değişince", "Her zaman"]);
    dd.set_selected(match s.battery_mode {
        BatteryMode::Off => 0,
        BatteryMode::OnChange => 1,
        BatteryMode::Always => 2,
    });
    dd.connect_selected_notify(clone!(@strong settings => move |dd| {
        let mode = match dd.selected() {
            0 => BatteryMode::Off,
            2 => BatteryMode::Always,
            _ => BatteryMode::OnChange,
        };
        settings.borrow_mut().battery_mode = mode;
        settings.borrow().save();
    }));
    battery_row.append(&dd);
    root.append(&battery_row);

    root.append(&gtk::Label::new(Some("Bazı ayarlar bir sonraki açılışta tam etkili olur.")));

    win.set_child(Some(&root));
    win.present();
}

fn heading(text: &str) -> gtk::Label {
    let l = gtk::Label::new(Some(text));
    l.set_xalign(0.0);
    l.add_css_class("title-4");
    l
}

fn switch_row<F: Fn(bool) + 'static>(title: &str, initial: bool, on_change: F) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    let label = gtk::Label::new(Some(title));
    label.set_xalign(0.0);
    label.set_hexpand(true);
    row.append(&label);

    let sw = gtk::Switch::new();
    sw.set_active(initial);
    sw.connect_active_notify(move |s| on_change(s.is_active()));
    sw.set_valign(gtk::Align::Center);
    row.append(&sw);
    row
}
