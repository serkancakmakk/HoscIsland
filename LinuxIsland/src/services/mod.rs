//! System-integration services. Each maps a macOS data source to its Linux
//! D-Bus / kernel equivalent and pushes updates into the UI.
//!
//!   mpris         → now-playing + transport controls (replaces AppleScript)
//!   battery       → sysfs poll (replaces IOKit)
//!   volume        → wpctl / PipeWire (replaces CoreAudio)
//!   screenshots   → inotify on the screenshot dir
//!   notifications → org.freedesktop.Notifications monitor (replaces NC database)

pub mod battery;
pub mod clipboard;
pub mod devices;
pub mod devices_battery;
pub mod downloads;
pub mod gmail;
pub mod hud;
pub mod lyrics;
pub mod mpris;
pub mod notifications;
pub mod screenshots;
pub mod volume;
pub mod weather;
pub mod windows;
