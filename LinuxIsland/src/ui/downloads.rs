//! Recent-downloads strip: chips for the newest files in ~/Downloads, each
//! click-to-open and draggable out. Linux counterpart of the macOS
//! `downloadsStrip` in the expanded card's drawer.

use std::path::{Path, PathBuf};
use std::process::Command;

use gtk::gio;
use gtk::glib::clone;
use gtk::prelude::*;

#[derive(Clone)]
pub struct DownloadsView {
    pub container: gtk::Box,
    row: gtk::Box,
}

impl DownloadsView {
    pub fn build() -> Self {
        let container = gtk::Box::new(gtk::Orientation::Vertical, 4);
        container.add_css_class("controls");

        let title = gtk::Label::new(Some(crate::i18n::t("İndirilenler", "Downloads")));
        title.add_css_class("subtitle");
        title.set_xalign(0.0);
        container.append(&title);

        let row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
        container.append(&row);
        container.set_visible(false);

        DownloadsView { container, row }
    }

    pub fn set(&self, files: Vec<PathBuf>) {
        while let Some(child) = self.row.first_child() {
            self.row.remove(&child);
        }
        self.container.set_visible(!files.is_empty());
        for path in files {
            self.row.append(&self.chip(path));
        }
    }

    fn chip(&self, path: PathBuf) -> gtk::Box {
        let chip = gtk::Box::new(gtk::Orientation::Horizontal, 4);
        chip.add_css_class("chip");

        let icon = gtk::Image::from_icon_name("text-x-generic");
        chip.append(&icon);

        let label = gtk::Label::new(Some(&display_name(&path)));
        label.set_ellipsize(gtk::pango::EllipsizeMode::Middle);
        label.set_max_width_chars(14);
        chip.append(&label);

        // Click opens with the default handler.
        let click = gtk::GestureClick::new();
        click.connect_released(clone!(@strong path => move |_, _, _, _| {
            let _ = Command::new("xdg-open").arg(&path).spawn();
        }));
        chip.add_controller(click);

        // Drag the file back out.
        let source = gtk::DragSource::new();
        source.set_actions(gtk::gdk::DragAction::COPY);
        source.connect_prepare(clone!(@strong path => move |_, _, _| {
            let file = gio::File::for_path(&path);
            Some(gtk::gdk::ContentProvider::for_value(&file.to_value()))
        }));
        chip.add_controller(source);

        // Right-click → share menu (Linux counterpart of the macOS context menu).
        let menu = gtk::GestureClick::new();
        menu.set_button(3);
        menu.connect_pressed(clone!(@strong path, @strong chip => move |_, _, x, y| {
            share_popover(&chip, &path, x, y);
        }));
        chip.add_controller(menu);

        chip
    }
}

/// Pop up a small menu of file actions at (x, y) relative to `anchor`.
fn share_popover(anchor: &gtk::Box, path: &Path, x: f64, y: f64) {
    let path = path.to_path_buf();
    let pop = gtk::Popover::new();
    pop.set_parent(anchor);
    pop.set_pointing_to(Some(&gtk::gdk::Rectangle::new(x as i32, y as i32, 1, 1)));
    pop.set_has_arrow(false);
    pop.connect_closed(|p| p.unparent());

    let box_ = gtk::Box::new(gtk::Orientation::Vertical, 2);
    let add = |label: &str| -> gtk::Button {
        let b = gtk::Button::with_label(label);
        b.add_css_class("flat");
        b.set_halign(gtk::Align::Fill);
        box_.append(&b);
        b
    };

    let email = add(crate::i18n::t("E-posta ile gönder", "Send via email"));
    email.connect_clicked(clone!(@strong path, @strong pop => move |_| {
        let _ = Command::new("xdg-email").arg("--attach").arg(&path).spawn();
        pop.popdown();
    }));

    let copy = add(crate::i18n::t("Yolu kopyala", "Copy path"));
    copy.connect_clicked(clone!(@strong path, @strong pop => move |_| {
        crate::services::clipboard::copy(&path.to_string_lossy());
        pop.popdown();
    }));

    let folder = add(crate::i18n::t("Klasörü aç", "Open folder"));
    folder.connect_clicked(clone!(@strong path, @strong pop => move |_| {
        if let Some(dir) = path.parent() {
            let _ = Command::new("xdg-open").arg(dir).spawn();
        }
        pop.popdown();
    }));

    pop.set_child(Some(&box_));
    pop.popup();
}

fn display_name(path: &Path) -> String {
    path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default()
}
