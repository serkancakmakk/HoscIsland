//! Battery state from sysfs (`/sys/class/power_supply`).
//!
//! Linux equivalent of the macOS `BatteryMonitor` (IOKit). A short poll is plenty
//! for a status indicator and keeps us dependency-free; UPower could replace this
//! later for event-driven plug/unplug.

use std::fs;
use std::time::Duration;

use gtk::glib;

use crate::model::Battery;

/// Poll every 5s and invoke `on_change` (on the UI thread) when the reading moves.
pub fn start<F: Fn(Option<Battery>) + 'static>(on_change: F) {
    glib::spawn_future_local(async move {
        let mut last: Option<Battery> = None;
        loop {
            let now = read();
            if now != last {
                last = now;
                on_change(now);
            }
            glib::timeout_future(Duration::from_secs(5)).await;
        }
    });
}

fn read() -> Option<Battery> {
    let dir = fs::read_dir("/sys/class/power_supply").ok()?;
    for entry in dir.flatten() {
        let name = entry.file_name();
        if !name.to_string_lossy().starts_with("BAT") {
            continue;
        }
        let base = entry.path();
        let percentage = fs::read_to_string(base.join("capacity"))
            .ok()?
            .trim()
            .parse::<u8>()
            .ok()?;
        let status = fs::read_to_string(base.join("status")).unwrap_or_default();
        let charging = matches!(status.trim(), "Charging" | "Full");
        return Some(Battery { percentage, charging });
    }
    None
}
