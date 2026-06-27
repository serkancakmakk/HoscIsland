//! Gmail strip: recent unread (sender — subject); click opens it in the browser.

use std::process::Command;

use gtk::glib::clone;
use gtk::prelude::*;

use crate::services::gmail::Mail;

#[derive(Clone)]
pub struct GmailView {
    pub container: gtk::Box,
    list: gtk::Box,
    unread: gtk::Label,
}

impl GmailView {
    pub fn build() -> Self {
        let container = gtk::Box::new(gtk::Orientation::Vertical, 4);
        container.add_css_class("controls");

        let header = gtk::Box::new(gtk::Orientation::Horizontal, 6);
        let title = gtk::Label::new(Some("Gmail"));
        title.add_css_class("subtitle");
        title.set_hexpand(true);
        title.set_xalign(0.0);
        let unread = gtk::Label::new(None);
        unread.add_css_class("badge");
        header.append(&title);
        header.append(&unread);
        container.append(&header);

        let list = gtk::Box::new(gtk::Orientation::Vertical, 3);
        container.append(&list);
        container.set_visible(false);

        GmailView { container, list, unread }
    }

    pub fn set(&self, unread: u32, messages: Vec<Mail>) {
        self.unread.set_text(&if unread > 0 { unread.to_string() } else { String::new() });
        while let Some(child) = self.list.first_child() {
            self.list.remove(&child);
        }
        self.container.set_visible(!messages.is_empty());
        for m in messages.into_iter().take(6) {
            self.list.append(&self.entry(m));
        }
    }

    fn entry(&self, mail: Mail) -> gtk::Button {
        let btn = gtk::Button::new();
        btn.add_css_class("flat");
        btn.add_css_class("chip");

        let box_ = gtk::Box::new(gtk::Orientation::Vertical, 0);
        let author = gtk::Label::new(Some(&mail.author));
        author.set_xalign(0.0);
        author.add_css_class("title");
        author.set_ellipsize(gtk::pango::EllipsizeMode::End);
        let subject = gtk::Label::new(Some(&mail.title));
        subject.set_xalign(0.0);
        subject.add_css_class("subtitle");
        subject.set_ellipsize(gtk::pango::EllipsizeMode::End);
        box_.append(&author);
        box_.append(&subject);
        btn.set_child(Some(&box_));

        btn.connect_clicked(clone!(@strong mail => move |_| {
            let url = if mail.link.is_empty() {
                "https://mail.google.com/mail/u/0/#inbox"
            } else {
                mail.link.as_str()
            };
            let _ = Command::new("xdg-open").arg(url).spawn();
        }));
        btn
    }
}
