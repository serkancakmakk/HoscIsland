//! Connected-accessory battery strip: name + percentage chips. Linux counterpart
//! of the macOS `devicesStrip` in the expanded card's drawer.

use gtk::prelude::*;

use crate::model::DeviceBattery;

#[derive(Clone)]
pub struct DevicesView {
    pub container: gtk::Box,
    row: gtk::Box,
}

impl DevicesView {
    pub fn build() -> Self {
        let container = gtk::Box::new(gtk::Orientation::Vertical, 4);
        container.add_css_class("controls");

        let title = gtk::Label::new(Some(crate::i18n::t("Cihazlar", "Devices")));
        title.add_css_class("subtitle");
        title.set_xalign(0.0);
        container.append(&title);

        let row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
        container.append(&row);
        container.set_visible(false);

        DevicesView { container, row }
    }

    pub fn set(&self, devices: Vec<DeviceBattery>) {
        while let Some(child) = self.row.first_child() {
            self.row.remove(&child);
        }
        self.container.set_visible(!devices.is_empty());
        for d in devices {
            self.row.append(&self.chip(&d));
        }
    }

    fn chip(&self, dev: &DeviceBattery) -> gtk::Box {
        let chip = gtk::Box::new(gtk::Orientation::Horizontal, 5);
        chip.add_css_class("chip");

        let icon = gtk::Image::from_icon_name(icon_for(&dev.name));
        chip.append(&icon);

        let text = gtk::Box::new(gtk::Orientation::Vertical, 0);
        let name = gtk::Label::new(Some(&dev.name));
        name.set_xalign(0.0);
        name.add_css_class("title");
        name.set_ellipsize(gtk::pango::EllipsizeMode::End);
        let pct = gtk::Label::new(Some(&format!("{}%", dev.percentage)));
        pct.set_xalign(0.0);
        pct.add_css_class("subtitle");
        if dev.percentage <= 20 {
            pct.add_css_class("low");
        }
        text.append(&name);
        text.append(&pct);
        chip.append(&text);
        chip
    }
}

/// Map a device name to a themed icon (best effort).
fn icon_for(name: &str) -> &'static str {
    let n = name.to_lowercase();
    if n.contains("airpod") || n.contains("headphone") || n.contains("headset") || n.contains("buds") {
        "audio-headphones-symbolic"
    } else if n.contains("mouse") {
        "input-mouse-symbolic"
    } else if n.contains("keyboard") {
        "input-keyboard-symbolic"
    } else {
        "battery-symbolic"
    }
}
