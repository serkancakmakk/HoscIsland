//! System volume via WirePlumber's `wpctl` (PipeWire). Wraps the CLI to avoid
//! linking PipeWire — robust and dependency-light.
//!
//! Linux equivalent of the macOS CoreAudio volume slider.

use std::process::Command;

const SINK: &str = "@DEFAULT_AUDIO_SINK@";

/// Current volume in `0.0..=1.0`, or `None` if `wpctl` is unavailable.
pub fn get() -> Option<f64> {
    let out = Command::new("wpctl").args(["get-volume", SINK]).output().ok()?;
    if !out.status.success() {
        return None;
    }
    // Output looks like: "Volume: 0.55" (optionally " [MUTED]").
    let text = String::from_utf8_lossy(&out.stdout);
    text.split_whitespace().nth(1)?.parse::<f64>().ok()
}

/// Set volume from a `0.0..=1.0` fraction.
pub fn set(fraction: f64) {
    let v = fraction.clamp(0.0, 1.0);
    let _ = Command::new("wpctl")
        .args(["set-volume", SINK, &format!("{v:.2}")])
        .status();
}
