//! Settings window — Linux equivalent of the macOS `SettingsView`.
//!
//! Opened by right-clicking the island. Edits are written to the TOML config
//! immediately; layer-shell-affecting options (movable, interaction mode) take
//! full effect on the next launch.

use std::cell::RefCell;
use std::rc::Rc;

use gtk::glib::clone;
use gtk::prelude::*;

use crate::i18n::t;
use crate::settings::{BatteryMode, CornerStyle, HoverSensitivity, InteractionMode, Language, Settings};

pub fn show(settings: Rc<RefCell<Settings>>) {
    let win = gtk::Window::builder()
        .title(t("LinuxIsland Ayarları", "LinuxIsland Settings"))
        .default_width(360)
        .default_height(360)
        .build();

    let root = gtk::Box::new(gtk::Orientation::Vertical, 12);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(18);
    root.set_margin_end(18);

    root.append(&heading(t("Özellikler", "Features")));

    let s = settings.borrow().clone();

    root.append(&switch_row(t("Müzik göstergesi", "Music indicator"), s.show_music, clone!(@strong settings => move |on| {
        settings.borrow_mut().show_music = on; settings.borrow().save();
    })));
    root.append(&switch_row(t("Bildirim banner'ı", "Notification banner"), s.show_notifications, clone!(@strong settings => move |on| {
        settings.borrow_mut().show_notifications = on; settings.borrow().save();
    })));
    root.append(&switch_row(t("Ses kaydırıcısı", "Volume slider"), s.show_volume, clone!(@strong settings => move |on| {
        settings.borrow_mut().show_volume = on; settings.borrow().save();
    })));
    root.append(&switch_row(t("Tıkla ile aç (kapalı = hover)", "Click to open (off = hover)"), s.interaction_mode == InteractionMode::Click,
        clone!(@strong settings => move |on| {
            settings.borrow_mut().interaction_mode = if on { InteractionMode::Click } else { InteractionMode::Hover };
            settings.borrow().save();
        })));
    root.append(&switch_row(t("Taşınabilir ada", "Movable island"), s.movable, clone!(@strong settings => move |on| {
        settings.borrow_mut().movable = on; settings.borrow().save();
    })));
    // Autostart is backed by the .desktop file (its own source of truth).
    root.append(&switch_row(t("Açılışta başlat", "Launch at login"), crate::autostart::is_enabled(), |on| {
        crate::autostart::set(on);
    }));

    // Hover sensitivity dropdown.
    let hover_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    hover_row.append(&gtk::Label::new(Some(t("Hover hassasiyeti", "Hover sensitivity"))));
    let hspacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    hspacer.set_hexpand(true);
    hover_row.append(&hspacer);
    let hdd = gtk::DropDown::from_strings(&[t("Anında", "Instant"), "Normal", t("Rahat", "Relaxed")]);
    hdd.set_selected(match s.hover_sensitivity {
        HoverSensitivity::Fast => 0,
        HoverSensitivity::Normal => 1,
        HoverSensitivity::Relaxed => 2,
    });
    hdd.connect_selected_notify(clone!(@strong settings => move |dd| {
        let v = match dd.selected() {
            0 => HoverSensitivity::Fast,
            2 => HoverSensitivity::Relaxed,
            _ => HoverSensitivity::Normal,
        };
        settings.borrow_mut().hover_sensitivity = v;
        settings.borrow().save();
    }));
    hover_row.append(&hdd);
    root.append(&hover_row);

    // Battery mode dropdown.
    let battery_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    battery_row.append(&gtk::Label::new(Some(t("Pil göstergesi", "Battery indicator"))));
    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    battery_row.append(&spacer);
    let dd = gtk::DropDown::from_strings(&[t("Kapalı", "Off"), t("Değişince", "On change"), t("Her zaman", "Always")]);
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

    // Corner-rounding dropdown.
    let corner_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    corner_row.append(&gtk::Label::new(Some(t("Köşe yuvarlaklığı", "Corner rounding"))));
    let cspacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    cspacer.set_hexpand(true);
    corner_row.append(&cspacer);
    let cdd = gtk::DropDown::from_strings(&[t("Yumuşak", "Soft"), t("Orta", "Medium"), t("Keskin", "Sharp")]);
    cdd.set_selected(match s.corner_style {
        CornerStyle::Soft => 0,
        CornerStyle::Medium => 1,
        CornerStyle::Sharp => 2,
    });
    cdd.connect_selected_notify(clone!(@strong settings => move |dd| {
        let v = match dd.selected() {
            0 => CornerStyle::Soft,
            2 => CornerStyle::Sharp,
            _ => CornerStyle::Medium,
        };
        settings.borrow_mut().corner_style = v;
        settings.borrow().save();
    }));
    corner_row.append(&cdd);
    root.append(&corner_row);

    // Language dropdown (applies on restart).
    let lang_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    lang_row.append(&gtk::Label::new(Some(t("Dil", "Language"))));
    let lspacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    lspacer.set_hexpand(true);
    lang_row.append(&lspacer);
    let ldd = gtk::DropDown::from_strings(&[t("Sistem", "System"), "Türkçe", "English"]);
    ldd.set_selected(match s.language {
        Language::System => 0,
        Language::Turkish => 1,
        Language::English => 2,
    });
    ldd.connect_selected_notify(clone!(@strong settings => move |dd| {
        let v = match dd.selected() {
            1 => Language::Turkish,
            2 => Language::English,
            _ => Language::System,
        };
        settings.borrow_mut().language = v;
        settings.borrow().save();
    }));
    lang_row.append(&ldd);
    root.append(&lang_row);

    // Calendar (iCal URL).
    root.append(&heading(t("Takvim", "Calendar")));
    let cal_entry = gtk::Entry::new();
    cal_entry.set_placeholder_text(Some("https://…/basic.ics"));
    if let Some(u) = s.calendar_url.clone() {
        cal_entry.set_text(&u);
    }
    cal_entry.connect_changed(clone!(@strong settings => move |e| {
        let t = e.text().to_string();
        let v = if t.trim().is_empty() { None } else { Some(t.trim().to_owned()) };
        settings.borrow_mut().calendar_url = v;
        settings.borrow().save();
    }));
    root.append(&cal_entry);
    root.append(&gtk::Label::new(Some(t(
        "Takvimin gizli iCal adresini yapıştır (boştaki kartta sıradaki etkinlik).",
        "Paste your calendar's private iCal address (next event on the idle card).",
    ))));

    // Gmail.
    root.append(&heading("Gmail"));
    if s.gmail_connected() {
        let row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
        let lbl = gtk::Label::new(Some(&format!("{} {}", t("Bağlı:", "Connected:"), s.gmail_email.clone().unwrap_or_default())));
        lbl.set_hexpand(true);
        lbl.set_xalign(0.0);
        let disconnect = gtk::Button::with_label(t("Kaldır", "Remove"));
        disconnect.connect_clicked(clone!(@strong settings => move |_| {
            settings.borrow_mut().disconnect_gmail();
        }));
        row.append(&lbl);
        row.append(&disconnect);
        root.append(&row);
    } else {
        let email = gtk::Entry::new();
        email.set_placeholder_text(Some("ornek@gmail.com"));
        let pass = gtk::Entry::new();
        pass.set_placeholder_text(Some(t("Uygulama şifresi (16 hane)", "App password (16 chars)")));
        pass.set_visibility(false);
        let connect = gtk::Button::with_label(t("Bağla", "Connect"));
        connect.connect_clicked(clone!(@strong settings, @strong email, @strong pass => move |_| {
            let e = email.text().to_string();
            let p = pass.text().to_string();
            if !e.trim().is_empty() && !p.trim().is_empty() {
                settings.borrow_mut().connect_gmail(e, p);
                pass.set_text("");
            }
        }));
        root.append(&email);
        root.append(&pass);
        root.append(&connect);
    }

    root.append(&gtk::Label::new(Some(t(
        "Gmail için 2FA + Uygulama Şifresi gerekir. Ayarları değiştirince uygulamayı yeniden başlat.",
        "Gmail needs 2FA + an App Password. Restart the app after changing settings.",
    ))));

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
