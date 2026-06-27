//! Connected-accessory batteries from sysfs (`/sys/class/power_supply`).
//!
//! Bluetooth/HID accessories (mouse, keyboard, headset) expose a power-supply
//! node with `scope=Device` and a `model_name`, separate from the laptop's own
//! `scope=System` battery. Linux counterpart of the macOS `DeviceBatteryManager`
//! (which parses `ioreg`).

use std::fs;
use std::time::Duration;

use gtk::glib;

use crate::model::DeviceBattery;

/// Poll every 60s and invoke `on_change` (on the UI thread) when the set moves.
pub fn start<F: Fn(Vec<DeviceBattery>) + 'static>(on_change: F) {
    glib::spawn_future_local(async move {
        let mut last: Vec<DeviceBattery> = Vec::new();
        loop {
            let now = read();
            if now != last {
                last = now.clone();
                on_change(now);
            }
            glib::timeout_future(Duration::from_secs(60)).await;
        }
    });
}

fn read() -> Vec<DeviceBattery> {
    let mut out = Vec::new();
    let Ok(dir) = fs::read_dir("/sys/class/power_supply") else {
        return out;
    };
    for entry in dir.flatten() {
        let base = entry.path();
        // Only accessory batteries (scope=Device); skip the system battery & AC.
        let scope = fs::read_to_string(base.join("scope")).unwrap_or_default();
        if scope.trim() != "Device" {
            continue;
        }
        let Some(percentage) = fs::read_to_string(base.join("capacity"))
            .ok()
            .and_then(|s| s.trim().parse::<u8>().ok())
        else {
            continue;
        };
        if percentage == 0 {
            continue;
        }
        let name = fs::read_to_string(base.join("model_name"))
            .ok()
            .map(|s| s.trim().to_owned())
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| entry.file_name().to_string_lossy().into_owned());
        out.push(DeviceBattery { name, percentage });
    }
    out
}
