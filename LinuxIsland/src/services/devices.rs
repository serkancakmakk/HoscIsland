//! Device/volume event flashes via GIO's `VolumeMonitor`.
//!
//! Linux equivalent of the macOS `NSWorkspace` mount notifications. Fires
//! `on_event(title, name)` when a drive/volume is mounted or removed.

use std::rc::Rc;

use gtk::gio;
use gtk::gio::prelude::*;

pub fn start<F: Fn(&str, String) + 'static>(on_event: F) {
    let monitor = gio::VolumeMonitor::get();
    let cb: Rc<dyn Fn(&str, String)> = Rc::new(on_event);

    let added = cb.clone();
    monitor.connect_mount_added(move |_, mount| {
        (*added)("Bağlandı", mount.name().to_string());
    });
    let removed = cb.clone();
    monitor.connect_mount_removed(move |_, mount| {
        (*removed)("Çıkarıldı", mount.name().to_string());
    });

    // The monitor is a process-wide singleton; keep our handle so the handlers
    // live for the app's lifetime.
    std::mem::forget(monitor);
}
