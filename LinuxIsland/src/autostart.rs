//! Launch-at-login via an XDG autostart `.desktop` entry.
//!
//! Linux equivalent of the macOS `LoginItem` (SMAppService). Writes/removes
//! `~/.config/autostart/linux-island.desktop`, which compliant desktops run on
//! session start.

use std::fs;
use std::path::PathBuf;

fn desktop_path() -> Option<PathBuf> {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
    Some(base.join("autostart").join("linux-island.desktop"))
}

pub fn is_enabled() -> bool {
    desktop_path().map(|p| p.exists()).unwrap_or(false)
}

pub fn set(enabled: bool) {
    let Some(path) = desktop_path() else { return };
    if enabled {
        if let Some(dir) = path.parent() {
            let _ = fs::create_dir_all(dir);
        }
        let exec = std::env::current_exe()
            .map(|p| p.to_string_lossy().into_owned())
            .unwrap_or_else(|_| "linux-island".to_owned());
        let entry = format!(
            "[Desktop Entry]\n\
             Type=Application\n\
             Name=LinuxIsland\n\
             Exec={exec}\n\
             X-GNOME-Autostart-enabled=true\n"
        );
        let _ = fs::write(path, entry);
    } else {
        let _ = fs::remove_file(path);
    }
}
