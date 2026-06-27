//! Brightness/volume HUD source: polls both and reports changes, so the island
//! can show its own indicator. Mirror of the macOS `SystemMonitor`.
//!
//! Brightness from `/sys/class/backlight`, volume from `wpctl` (via [`super::volume`]).

use std::cell::Cell;
use std::rc::Rc;
use std::time::Duration;

use gtk::glib;

use super::volume;

#[derive(Clone, Copy, Debug)]
pub enum HudKind {
    Brightness,
    Volume,
}

/// Poll every 0.4s; `on_change(kind, level 0..1)` fires on the UI thread.
pub fn start<F: Fn(HudKind, f64) + 'static>(on_change: F) {
    let last_b = Rc::new(Cell::new(-1.0_f64));
    let last_v = Rc::new(Cell::new(-1.0_f64));

    glib::timeout_add_local(Duration::from_millis(400), move || {
        if let Some(b) = brightness() {
            if last_b.get() >= 0.0 && (b - last_b.get()).abs() > 0.005 {
                on_change(HudKind::Brightness, b);
            }
            last_b.set(b);
        }
        if let Some(v) = volume::get() {
            if last_v.get() >= 0.0 && (v - last_v.get()).abs() > 0.005 {
                on_change(HudKind::Volume, v);
            }
            last_v.set(v);
        }
        glib::ControlFlow::Continue
    });
}

fn brightness() -> Option<f64> {
    for entry in std::fs::read_dir("/sys/class/backlight").ok()?.flatten() {
        let base = entry.path();
        let cur: f64 = std::fs::read_to_string(base.join("brightness")).ok()?.trim().parse().ok()?;
        let max: f64 = std::fs::read_to_string(base.join("max_brightness")).ok()?.trim().parse().ok()?;
        if max > 0.0 {
            return Some((cur / max).clamp(0.0, 1.0));
        }
    }
    None
}
