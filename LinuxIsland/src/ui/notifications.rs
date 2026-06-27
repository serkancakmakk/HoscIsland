//! Notification-history list: recent notifications (newest first) with the
//! sending app + text, and a "Temizle" to clear. Linux counterpart of the macOS
//! `notificationsStrip` in the expanded card's drawer.

use std::cell::Cell;
use std::rc::Rc;

use gtk::glib::clone;
use gtk::prelude::*;

use crate::model::Notification;

/// Keep the history short so the drawer never grows unbounded — mirrors macOS.
const MAX_HISTORY: u32 = 12;

#[derive(Clone)]
pub struct NotificationsView {
    pub container: gtk::Box,
    list: gtk::Box,
    count: Rc<Cell<u32>>,
}

impl NotificationsView {
    pub fn build() -> Self {
        let container = gtk::Box::new(gtk::Orientation::Vertical, 4);
        container.add_css_class("controls");

        let header = gtk::Box::new(gtk::Orientation::Horizontal, 6);
        let title = gtk::Label::new(Some("Bildirimler"));
        title.add_css_class("subtitle");
        title.set_hexpand(true);
        title.set_xalign(0.0);
        let clear = gtk::Button::with_label("Temizle");
        clear.add_css_class("flat");
        header.append(&title);
        header.append(&clear);
        container.append(&header);

        let list = gtk::Box::new(gtk::Orientation::Vertical, 3);
        container.append(&list);
        container.set_visible(false);

        let count = Rc::new(Cell::new(0u32));
        clear.connect_clicked(clone!(@strong list, @strong container, @strong count => move |_| {
            while let Some(child) = list.first_child() {
                list.remove(&child);
            }
            count.set(0);
            container.set_visible(false);
        }));

        NotificationsView { container, list, count }
    }

    /// Prepend a notification, capping the list at `MAX_HISTORY`.
    pub fn push(&self, note: &Notification) {
        let entry = self.entry(note);
        // `insert_child_after(child, None)` puts it at the very top (newest first).
        self.list.insert_child_after(&entry, None::<&gtk::Widget>);
        let n = self.count.get() + 1;
        if n > MAX_HISTORY {
            if let Some(last) = self.list.last_child() {
                self.list.remove(&last);
            }
        } else {
            self.count.set(n);
        }
        self.container.set_visible(true);
    }

    fn entry(&self, note: &Notification) -> gtk::Box {
        let row = gtk::Box::new(gtk::Orientation::Horizontal, 7);
        row.add_css_class("chip");

        let icon = gtk::Image::from_icon_name("preferences-system-notifications-symbolic");
        row.append(&icon);

        let text = gtk::Box::new(gtk::Orientation::Vertical, 0);
        text.set_hexpand(true);
        let sender = if note.summary.is_empty() { note.app.clone() } else { note.summary.clone() };
        let sender_lbl = gtk::Label::new(Some(&sender));
        sender_lbl.set_xalign(0.0);
        sender_lbl.add_css_class("title");
        sender_lbl.set_ellipsize(gtk::pango::EllipsizeMode::End);
        text.append(&sender_lbl);
        if !note.body.is_empty() {
            let body_lbl = gtk::Label::new(Some(&note.body));
            body_lbl.set_xalign(0.0);
            body_lbl.add_css_class("subtitle");
            body_lbl.set_ellipsize(gtk::pango::EllipsizeMode::End);
            text.append(&body_lbl);
        }
        row.append(&text);
        row
    }
}
