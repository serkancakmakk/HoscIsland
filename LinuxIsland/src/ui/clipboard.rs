//! Clipboard-history strip: recent copies as chips; click to copy back.

use gtk::glib::clone;
use gtk::prelude::*;

use crate::services::clipboard;

#[derive(Clone)]
pub struct ClipboardView {
    pub container: gtk::Box,
    row: gtk::Box,
}

impl ClipboardView {
    pub fn build() -> Self {
        let container = gtk::Box::new(gtk::Orientation::Vertical, 4);
        container.add_css_class("controls");

        let title = gtk::Label::new(Some(crate::i18n::t("Pano", "Clipboard")));
        title.add_css_class("subtitle");
        title.set_xalign(0.0);
        container.append(&title);

        let row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
        container.append(&row);
        container.set_visible(false);

        ClipboardView { container, row }
    }

    pub fn set_items(&self, items: Vec<String>) {
        while let Some(child) = self.row.first_child() {
            self.row.remove(&child);
        }
        self.container.set_visible(!items.is_empty());
        for item in items.into_iter().take(6) {
            let label = first_line(&item);
            let btn = gtk::Button::with_label(&label);
            btn.add_css_class("flat");
            btn.add_css_class("chip");
            btn.set_tooltip_text(Some(&item));
            btn.connect_clicked(clone!(@strong item => move |_| clipboard::copy(&item)));
            self.row.append(&btn);
        }
    }
}

fn first_line(text: &str) -> String {
    let line = text.trim().lines().next().unwrap_or("").trim();
    if line.chars().count() > 20 {
        format!("{}…", line.chars().take(20).collect::<String>())
    } else {
        line.to_owned()
    }
}
