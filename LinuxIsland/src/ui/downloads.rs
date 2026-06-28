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

        chip
    }
}

fn display_name(path: &Path) -> String {
    path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default()
}
