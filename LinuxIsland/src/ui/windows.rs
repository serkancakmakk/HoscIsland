//! Open-windows switcher strip: chips per window; click focuses it.

use gtk::glib::clone;
use gtk::prelude::*;

use crate::services::windows::{self, Win};

#[derive(Clone)]
pub struct WindowsView {
    pub container: gtk::Box,
    row: gtk::Box,
}

impl WindowsView {
    pub fn build() -> Self {
        let container = gtk::Box::new(gtk::Orientation::Vertical, 4);
        container.add_css_class("controls");

        let title = gtk::Label::new(Some(crate::i18n::t("Pencereler", "Windows")));
        title.add_css_class("subtitle");
        title.set_xalign(0.0);
        container.append(&title);

        let row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
        container.append(&row);
        container.set_visible(false);

        WindowsView { container, row }
    }

    pub fn set(&self, wins: Vec<Win>) {
        while let Some(child) = self.row.first_child() {
            self.row.remove(&child);
        }
        self.container.set_visible(!wins.is_empty());
        for win in wins {
            self.row.append(&self.chip(win));
        }
    }

    fn chip(&self, win: Win) -> gtk::Button {
        let btn = gtk::Button::new();
        btn.add_css_class("flat");
        btn.add_css_class("chip");
        btn.set_tooltip_text(Some(&format!("{} — {}", win.app, win.title)));

        let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
        col.set_halign(gtk::Align::Center);
        let icon = gtk::Image::from_icon_name(&win.app.to_lowercase());
        icon.set_pixel_size(24);
        let label = gtk::Label::new(Some(&win.title));
        label.add_css_class("subtitle");
        label.set_ellipsize(gtk::pango::EllipsizeMode::End);
        label.set_max_width_chars(10);
        col.append(&icon);
        col.append(&label);
        btn.set_child(Some(&col));

        let id = win.id.clone();
        btn.connect_clicked(clone!(@strong id => move |_| windows::focus(&id)));
        btn
    }
}
