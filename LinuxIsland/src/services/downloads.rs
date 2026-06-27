//! Recent files from the user's Downloads folder (newest first).
//!
//! Linux counterpart of the macOS `DownloadsManager`. A short poll keeps it
//! dependency-free; surfaces the most recent regular files for quick access.

use std::path::PathBuf;
use std::time::{Duration, SystemTime};

use gtk::glib;

const MAX_ITEMS: usize = 8;

/// Poll every 8s and invoke `on_change` (on the UI thread) when the set moves.
pub fn start<F: Fn(Vec<PathBuf>) + 'static>(on_change: F) {
    glib::spawn_future_local(async move {
        let mut last: Vec<PathBuf> = Vec::new();
        loop {
            let now = read();
            if now != last {
                last = now.clone();
                on_change(now);
            }
            glib::timeout_future(Duration::from_secs(8)).await;
        }
    });
}

/// `$XDG_DOWNLOAD_DIR`, falling back to `$HOME/Downloads`.
fn downloads_dir() -> Option<PathBuf> {
    if let Ok(dir) = std::env::var("XDG_DOWNLOAD_DIR") {
        if !dir.is_empty() {
            return Some(PathBuf::from(dir));
        }
    }
    std::env::var("HOME").ok().map(|h| PathBuf::from(h).join("Downloads"))
}

fn read() -> Vec<PathBuf> {
    let Some(dir) = downloads_dir() else {
        return Vec::new();
    };
    let Ok(entries) = std::fs::read_dir(&dir) else {
        return Vec::new();
    };

    let mut files: Vec<(SystemTime, PathBuf)> = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        let Ok(meta) = entry.metadata() else { continue };
        if !meta.is_file() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().into_owned();
        // Skip hidden files and browsers' in-progress downloads.
        if name.starts_with('.') {
            continue;
        }
        let ext = path
            .extension()
            .and_then(|e| e.to_str())
            .map(|s| s.to_lowercase())
            .unwrap_or_default();
        if matches!(ext.as_str(), "crdownload" | "part" | "download") {
            continue;
        }
        let mtime = meta.modified().unwrap_or(SystemTime::UNIX_EPOCH);
        files.push((mtime, path));
    }

    files.sort_by(|a, b| b.0.cmp(&a.0));
    files.into_iter().take(MAX_ITEMS).map(|(_, p)| p).collect()
}
