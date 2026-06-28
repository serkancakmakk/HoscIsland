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

        // Right-click → focus / close menu (parity with the macOS context menu).
        let menu = gtk::GestureClick::new();
        menu.set_button(3);
        menu.connect_pressed(clone!(@strong btn, @strong id => move |_, _, x, y| {
            window_menu(&btn, &id, x, y);
        }));
        btn.add_controller(menu);
        btn
    }
}

/// Pop up a focus/close menu for a window at (x, y) relative to `anchor`.
fn window_menu(anchor: &gtk::Button, id: &str, x: f64, y: f64) {
    let id = id.to_owned();
    let pop = gtk::Popover::new();
    pop.set_parent(anchor);
    pop.set_pointing_to(Some(&gtk::gdk::Rectangle::new(x as i32, y as i32, 1, 1)));
    pop.set_has_arrow(false);
    pop.connect_closed(|p| p.unparent());

    let box_ = gtk::Box::new(gtk::Orientation::Vertical, 2);
    let focus = gtk::Button::with_label(crate::i18n::t("Öne getir", "Bring to front"));
    focus.add_css_class("flat");
    focus.connect_clicked(clone!(@strong id, @strong pop => move |_| {
        windows::focus(&id);
        pop.popdown();
    }));
    let close = gtk::Button::with_label(crate::i18n::t("Pencereyi kapat", "Close window"));
    close.add_css_class("flat");
    close.connect_clicked(clone!(@strong id, @strong pop => move |_| {
        windows::close(&id);
        pop.popdown();
    }));
    box_.append(&focus);
    box_.append(&close);
    pop.set_child(Some(&box_));
    pop.popup();
}
