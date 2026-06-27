//! File-shelf widget: chips for dropped files/apps, each draggable back out and
//! click-to-open (apps launch, files open). A "+ Uygulama" button adds `.desktop`
//! apps, and "Temizle" clears.
//!
//! Mirror of the macOS shelf. Drops are accepted by the island root (see
//! `island.rs`), which forwards paths here via [`ShelfView::add_paths`].

use std::cell::RefCell;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::rc::Rc;

use gtk::gio;
use gtk::glib::clone;
use gtk::prelude::*;

use crate::shelf::ShelfStore;

#[derive(Clone)]
pub struct ShelfView {
    pub container: gtk::Box,
    row: gtk::Box,
    placeholder: gtk::Label,
    store: Rc<RefCell<ShelfStore>>,
}

impl ShelfView {
    pub fn build(store: Rc<RefCell<ShelfStore>>) -> Self {
        let container = gtk::Box::new(gtk::Orientation::Vertical, 4);
        container.add_css_class("controls");
        container.add_css_class("shelf");

        // Header: title + add-app + clear.
        let header = gtk::Box::new(gtk::Orientation::Horizontal, 6);
        let title = gtk::Label::new(Some("Raf"));
        title.add_css_class("subtitle");
        title.set_hexpand(true);
        title.set_xalign(0.0);
        let add_app = gtk::Button::with_label("＋ Uygulama");
        add_app.add_css_class("flat");
        let clear = gtk::Button::with_label("Temizle");
        clear.add_css_class("flat");
        header.append(&title);
        header.append(&add_app);
        header.append(&clear);
        container.append(&header);

        let row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
        container.append(&row);

        let placeholder = gtk::Label::new(Some("Dosya sürükle ya da ＋ ile uygulama ekle"));
        placeholder.add_css_class("subtitle");
        container.append(&placeholder);

        let view = ShelfView { container, row, placeholder, store };

        clear.connect_clicked(clone!(@strong view => move |_| {
            view.store.borrow_mut().clear();
            view.repopulate();
        }));
        add_app.connect_clicked(clone!(@strong view => move |_| view.pick_app()));

        view.repopulate();
        view
    }

    /// Add dropped/picked paths and refresh.
    pub fn add_paths(&self, paths: Vec<PathBuf>) {
        {
            let mut store = self.store.borrow_mut();
            for p in paths {
                store.add(p);
            }
        }
        self.repopulate();
    }

    /// Open a file chooser for `.desktop` apps and add the chosen ones.
    fn pick_app(&self) {
        let dialog = gtk::FileDialog::builder().title("Uygulama ekle").build();
        dialog.set_initial_folder(Some(&gio::File::for_path("/usr/share/applications")));

        let filter = gtk::FileFilter::new();
        filter.set_name(Some("Uygulamalar (.desktop)"));
        filter.add_pattern("*.desktop");
        let filters = gio::ListStore::new::<gtk::FileFilter>();
        filters.append(&filter);
        dialog.set_filters(Some(&filters));

        let view = self.clone();
        dialog.open_multiple(
            None::<&gtk::Window>,
            gio::Cancellable::NONE,
            move |res| {
                if let Ok(list) = res {
                    let mut paths = Vec::new();
                    for i in 0..list.n_items() {
                        if let Some(file) = list.item(i).and_downcast::<gio::File>() {
                            if let Some(p) = file.path() {
                                paths.push(p);
                            }
                        }
                    }
                    if !paths.is_empty() {
                        view.add_paths(paths);
                    }
                }
            },
        );
    }

    fn repopulate(&self) {
        while let Some(child) = self.row.first_child() {
            self.row.remove(&child);
        }
        let items: Vec<PathBuf> = self.store.borrow().items().to_vec();
        self.placeholder.set_visible(items.is_empty());
        self.row.set_visible(!items.is_empty());
        for path in items {
            self.row.append(&self.chip(path));
        }
    }

    fn chip(&self, path: PathBuf) -> gtk::Box {
        let chip = gtk::Box::new(gtk::Orientation::Horizontal, 4);
        chip.add_css_class("chip");

        let icon = gtk::Image::from_icon_name(&icon_name(&path));
        chip.append(&icon);

        let label = gtk::Label::new(Some(&display_name(&path)));
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

        // Click to launch (apps) / open (files).
        let click = gtk::GestureClick::new();
        click.connect_released(clone!(@strong path => move |_, _, _, _| launch(&path)));
        chip.add_controller(click);

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

/// Launch a `.desktop` app, otherwise open the file with the default handler.
fn launch(path: &Path) {
    let is_desktop = path.extension().and_then(|e| e.to_str()) == Some("desktop");
    if is_desktop {
        let _ = Command::new("gio").arg("launch").arg(path).spawn();
    } else {
        let _ = Command::new("xdg-open").arg(path).spawn();
    }
}

/// For a `.desktop` file use its `Name=`, otherwise the file name.
fn display_name(path: &Path) -> String {
    if path.extension().and_then(|e| e.to_str()) == Some("desktop") {
        if let Some(name) = desktop_field(path, "Name") {
            return name;
        }
    }
    path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default()
}

/// Icon name for the chip: a `.desktop`'s `Icon=`, else a generic file icon.
fn icon_name(path: &Path) -> String {
    if path.extension().and_then(|e| e.to_str()) == Some("desktop") {
        if let Some(icon) = desktop_field(path, "Icon") {
            return icon;
        }
        return "application-x-executable".to_owned();
    }
    "text-x-generic".to_owned()
}

/// Read a top-level `Key=Value` from a `.desktop` file.
fn desktop_field(path: &Path, key: &str) -> Option<String> {
    let content = std::fs::read_to_string(path).ok()?;
    for line in content.lines() {
        if let Some(value) = line.strip_prefix(key).and_then(|r| r.strip_prefix('=')) {
            return Some(value.trim().to_owned());
        }
    }
    None
}
