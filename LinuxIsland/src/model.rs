//! Shared UI state + transient content models.
//!
//! Mirror of the macOS `NotchModels` layer — plain data, no platform calls.

/// Now-playing track snapshot (filled by the MPRIS service).
#[derive(Clone, Debug, Default, PartialEq)]
pub struct Track {
    pub title: String,
    pub artist: String,
    pub album: String,
    /// Local path / URL to the cover art, if the player exposes one.
    pub art_url: Option<String>,
    /// MPRIS `mpris:trackid` object path (needed for seek/SetPosition).
    pub track_id: String,
    /// Track length in microseconds (0 if unknown).
    pub length_us: i64,
    pub playing: bool,
    pub shuffle: bool,
    /// MPRIS `LoopStatus`: "None" | "Track" | "Playlist".
    pub loop_status: String,
}

/// A transient screenshot preview with quick actions.
#[derive(Clone, Debug, PartialEq)]
pub struct ScreenshotPreview {
    pub path: String,
}

/// Battery state (from UPower / sysfs).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Battery {
    pub percentage: u8,
    pub charging: bool,
}

/// A connected accessory's battery (Bluetooth mouse / keyboard / headset).
/// macOS counterpart: `DeviceBattery` (read via `ioreg`).
#[derive(Clone, Debug, PartialEq)]
pub struct DeviceBattery {
    pub name: String,
    pub percentage: u8,
}

/// A transient notification banner (from org.freedesktop.Notifications).
#[derive(Clone, Debug, PartialEq)]
pub struct Notification {
    pub app: String,
    pub summary: String,
    pub body: String,
}

/// The whole app's observable state. Held behind `Rc<RefCell<…>>` and read by the
/// UI; services mutate it and ask the UI to refresh.
#[derive(Default)]
pub struct AppState {
    pub expanded: bool,
    pub hovering: bool,
    pub track: Option<Track>,
    pub screenshot: Option<ScreenshotPreview>,
    pub battery: Option<Battery>,
    pub notification: Option<Notification>,
    pub volume: f64,
    /// Custom drag offset from the default top-center anchor (px, +y = down).
    pub offset_x: i32,
    pub offset_y: i32,
}

impl AppState {
    /// The collapsed pill widens when there's compact content to show — mirrors
    /// the macOS `isCompact` rule.
    pub fn is_compact(&self) -> bool {
        self.track.is_some() || self.battery.is_some() || self.notification.is_some()
    }
}
