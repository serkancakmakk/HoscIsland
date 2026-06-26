//! Screenshot preview: watch the screenshots directory and surface new images.
//!
//! Linux equivalent of the macOS `ScreenshotWatcher` (which used a vnode
//! DispatchSource). Uses `notify` (inotify) and bounces events onto the GTK
//! thread via an async channel.

use std::path::PathBuf;
use std::time::Duration;

use gtk::glib;
use notify::{Event, EventKind, RecursiveMode, Watcher};

/// Quick actions on a screenshot file (mirror of macOS `ScreenshotActions`).
pub mod actions {
    use std::process::Command;

    pub fn open(path: &str) {
        let _ = Command::new("xdg-open").arg(path).status();
    }

    /// Copy the image to the Wayland clipboard via `wl-copy`.
    pub fn copy(path: &str) {
        if let Ok(bytes) = std::fs::read(path) {
            use std::io::Write;
            if let Ok(mut child) = Command::new("wl-copy")
                .args(["--type", "image/png"])
                .stdin(std::process::Stdio::piped())
                .spawn()
            {
                if let Some(stdin) = child.stdin.as_mut() {
                    let _ = stdin.write_all(&bytes);
                }
                let _ = child.wait();
            }
        }
    }

    pub fn reveal(path: &str) {
        // Open the containing folder.
        if let Some(dir) = std::path::Path::new(path).parent() {
            let _ = Command::new("xdg-open").arg(dir).status();
        }
    }

    pub fn delete(path: &str) {
        let _ = std::fs::remove_file(path);
    }
}

/// Start watching; `on_new` fires (on the UI thread) with each new image path.
pub fn start<F: Fn(String) + 'static>(on_new: F) {
    let Some(dir) = screenshot_dir() else {
        eprintln!("[screenshots] no screenshot directory found");
        return;
    };

    let (tx, rx) = async_channel::unbounded::<String>();

    // The notify watcher callback runs on a notify-owned thread; forward paths.
    let mut watcher = match notify::recommended_watcher(move |res: notify::Result<Event>| {
        if let Ok(event) = res {
            if matches!(event.kind, EventKind::Create(_)) {
                for path in event.paths {
                    if is_image(&path) {
                        let _ = tx.send_blocking(path.to_string_lossy().into_owned());
                    }
                }
            }
        }
    }) {
        Ok(w) => w,
        Err(e) => {
            eprintln!("[screenshots] watcher error: {e}");
            return;
        }
    };

    if let Err(e) = watcher.watch(&dir, RecursiveMode::NonRecursive) {
        eprintln!("[screenshots] watch error: {e}");
        return;
    }

    glib::spawn_future_local(async move {
        // Keep the watcher alive for the program's lifetime.
        let _watcher = watcher;
        while let Ok(path) = rx.recv().await {
            // Give the screenshot tool a beat to finish writing.
            glib::timeout_future(Duration::from_millis(150)).await;
            on_new(path);
        }
    });
}

fn screenshot_dir() -> Option<PathBuf> {
    let pics = std::env::var_os("XDG_PICTURES_DIR")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join("Pictures")))?;
    let shots = pics.join("Screenshots");
    Some(if shots.is_dir() { shots } else { pics })
}

fn is_image(path: &std::path::Path) -> bool {
    matches!(
        path.extension().and_then(|e| e.to_str()).map(|e| e.to_ascii_lowercase()),
        Some(ref e) if e == "png" || e == "jpg" || e == "jpeg"
    )
}
