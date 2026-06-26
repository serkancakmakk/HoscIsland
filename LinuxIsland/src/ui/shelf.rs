//! File-shelf widget: chips for dropped files, each draggable back out, with a
//! remove button and a "Temizle" (clear) action.
//!
//! Mirror of the macOS shelf strip. Drops are accepted by the island root (see
//! `island.rs`), which forwards paths here via [`ShelfView::add_paths`].

use std::cell::RefCell;
use std::path::PathBuf;
use std::rc::Rc;

use gtk::gio;
use gtk::glib::clone;
use gtk::prelude::*;

use crate::shelf::ShelfStore;

#[derive(Clone)]
pub struct ShelfView {
    pub container: gtk::Box,
    row: gtk::Box,
    store: Rc<RefCell<ShelfStore>>,
}

impl ShelfView {
    pub fn build(store: Rc<RefCell<ShelfStore>>) -> Self {
        let container = gtk::Box::new(gtk::Orientation::Vertical, 4);
        container.add_css_class("controls");
        container.add_css_class("shelf");

        let row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
        row.set_halign(gtk::Align::Center);
        container.append(&row);

        let clear = gtk::Button::with_label("Temizle");
        clear.add_css_class("flat");
        clear.set_halign(gtk::Align::End);
        container.append(&clear);

        let view = ShelfView { container, row, store };

        clear.connect_clicked(clone!(@strong view => move |_| {
            view.store.borrow_mut().clear();
            view.repopulate();
        }));

        view.repopulate();
        view
    }

    /// Add dropped files and refresh the chips.
    pub fn add_paths(&self, paths: Vec<PathBuf>) {
        {
            let mut store = self.store.borrow_mut();
            for p in paths {
                store.add(p);
            }
        }
        self.repopulate();
    }

    fn repopulate(&self) {
        while let Some(child) = self.row.first_child() {
            self.row.remove(&child);
        }
        let items: Vec<PathBuf> = self.store.borrow().items().to_vec();
        self.container.set_visible(!items.is_empty());
        for path in items {
            self.row.append(&self.chip(path));
        }
    }

    fn chip(&self, path: PathBuf) -> gtk::Box {
        let chip = gtk::Box::new(gtk::Orientation::Horizontal, 4);
        chip.add_css_class("chip");

        let icon = gtk::Image::from_icon_name("text-x-generic-symbolic");
        chip.append(&icon);

        let name = path
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default();
        let label = gtk::Label::new(Some(&name));
        label.set_ellipsize(gtk::pango::EllipsizeMode::Middle);
        label.set_max_width_chars(14);
        chip.append(&label);

        let remove = gtk::Button::from_icon_name("window-close-symbolic");
        remove.add_css_class("flat");
        chip.append(&remove);

        remove.connect_clicked(clone!(@strong self as view, @strong path => move |_| {
            view.store.borrow_mut().remove(&path);
            view.repopulate();
        }));

        // Drag the file back out of the shelf.
        let source = gtk::DragSource::new();
        source.set_actions(gtk::gdk::DragAction::COPY);
        source.connect_prepare(clone!(@strong path => move |_, _, _| {
            let file = gio::File::for_path(&path);
            Some(gtk::gdk::ContentProvider::for_value(&file.to_value()))
        }));
        chip.add_controller(source);

        chip
    }
}
