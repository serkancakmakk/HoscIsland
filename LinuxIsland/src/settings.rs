//! User settings, persisted as TOML at `~/.config/linux-island/config.toml`.
//!
//! Mirror of the macOS `Settings` (which used `UserDefaults`).

use std::fs;
use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum InteractionMode {
    Hover,
    Click,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum BatteryMode {
    Off,
    OnChange,
    Always,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    pub interaction_mode: InteractionMode,
    pub battery_mode: BatteryMode,
    pub show_music: bool,
    pub show_notifications: bool,
    pub show_volume: bool,
    pub movable: bool,
    pub offset_x: i32,
    pub offset_y: i32,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            interaction_mode: InteractionMode::Hover,
            battery_mode: BatteryMode::OnChange,
            show_music: true,
            show_notifications: true,
            show_volume: true,
            movable: false,
            offset_x: 0,
            offset_y: 0,
        }
    }
}

impl Settings {
    fn path() -> Option<PathBuf> {
        let base = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
        Some(base.join("linux-island").join("config.toml"))
    }

    /// Load from disk, falling back to defaults on any error.
    pub fn load() -> Self {
        let Some(p) = Self::path() else { return Self::default() };
        fs::read_to_string(p)
            .ok()
            .and_then(|s| toml::from_str(&s).ok())
            .unwrap_or_default()
    }

    /// Best-effort write to disk.
    pub fn save(&self) {
        let Some(p) = Self::path() else { return };
        if let Some(dir) = p.parent() {
            let _ = fs::create_dir_all(dir);
        }
        if let Ok(s) = toml::to_string_pretty(self) {
            let _ = fs::write(p, s);
        }
    }
}
