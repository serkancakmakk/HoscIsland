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

/// Corner rounding of the expanded island card.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum CornerStyle {
    Soft,
    Medium,
    Sharp,
}

impl CornerStyle {
    /// CSS class applied to the island root (Medium uses the default style).
    pub fn css_class(self) -> Option<&'static str> {
        match self {
            CornerStyle::Soft => Some("corner-soft"),
            CornerStyle::Medium => None,
            CornerStyle::Sharp => Some("corner-sharp"),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum BatteryMode {
    Off,
    OnChange,
    Always,
}

/// Hover open/close timing — how eagerly the island reacts to the cursor.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum HoverSensitivity {
    Fast,
    Normal,
    Relaxed,
}

impl HoverSensitivity {
    /// Delay before opening on hover (ms).
    pub fn open_ms(self) -> u64 {
        match self {
            HoverSensitivity::Fast => 0,
            HoverSensitivity::Normal => 120,
            HoverSensitivity::Relaxed => 300,
        }
    }
    /// Delay before collapsing after the cursor leaves (ms).
    pub fn close_ms(self) -> u64 {
        match self {
            HoverSensitivity::Fast => 120,
            HoverSensitivity::Normal => 180,
            HoverSensitivity::Relaxed => 450,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(default)]
pub struct Settings {
    pub interaction_mode: InteractionMode,
    pub hover_sensitivity: HoverSensitivity,
    pub battery_mode: BatteryMode,
    pub corner_style: CornerStyle,
    pub show_music: bool,
    pub show_notifications: bool,
    pub show_volume: bool,
    pub movable: bool,
    pub offset_x: i32,
    pub offset_y: i32,
    /// Connected Gmail address (the app password lives in a separate 0600 file).
    pub gmail_email: Option<String>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            interaction_mode: InteractionMode::Hover,
            hover_sensitivity: HoverSensitivity::Normal,
            battery_mode: BatteryMode::OnChange,
            corner_style: CornerStyle::Medium,
            show_music: true,
            show_notifications: true,
            show_volume: true,
            movable: false,
            offset_x: 0,
            offset_y: 0,
            gmail_email: None,
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

    pub fn gmail_connected(&self) -> bool {
        self.gmail_email.is_some() && Self::gmail_password().is_some()
    }

    fn gmail_password_path() -> Option<PathBuf> {
        Self::path().and_then(|p| p.parent().map(|d| d.join("gmail-pass")))
    }

    pub fn gmail_password() -> Option<String> {
        let p = Self::gmail_password_path()?;
        let s = fs::read_to_string(p).ok()?;
        let t = s.trim();
        if t.is_empty() { None } else { Some(t.to_owned()) }
    }

    /// Store the app password in a 0600 file alongside the config.
    pub fn connect_gmail(&mut self, email: String, app_password: String) {
        if let Some(p) = Self::gmail_password_path() {
            if let Some(dir) = p.parent() {
                let _ = fs::create_dir_all(dir);
            }
            if fs::write(&p, app_password.trim()).is_ok() {
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    let _ = fs::set_permissions(&p, fs::Permissions::from_mode(0o600));
                }
            }
        }
        self.gmail_email = Some(email.trim().to_owned());
        self.save();
    }

    pub fn disconnect_gmail(&mut self) {
        if let Some(p) = Self::gmail_password_path() {
            let _ = fs::remove_file(p);
        }
        self.gmail_email = None;
        self.save();
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
