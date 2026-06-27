//! Clipboard history via `wl-paste` polling (Wayland).
//!
//! Linux equivalent of the macOS `ClipboardManager`. Polls the selection every
//! ~0.8s, keeps the last few distinct text entries, and copies back with `wl-copy`.

use std::cell::RefCell;
use std::io::Write;
use std::process::{Command, Stdio};
use std::rc::Rc;
use std::time::Duration;

use gtk::glib;

const MAX: usize = 6;

/// Poll the clipboard; `on_change` (UI thread) gets the latest history list.
pub fn start<F: Fn(Vec<String>) + 'static>(on_change: F) {
    let history: Rc<RefCell<Vec<String>>> = Rc::new(RefCell::new(Vec::new()));
    let last = Rc::new(RefCell::new(String::new()));

    glib::timeout_add_local(Duration::from_millis(800), move || {
        if let Some(text) = read() {
            if !text.trim().is_empty() && *last.borrow() != text {
                *last.borrow_mut() = text.clone();
                let mut h = history.borrow_mut();
                h.retain(|x| x != &text);
                h.insert(0, text.clone());
                h.truncate(MAX);
                on_change(h.clone());
            }
        }
        glib::ControlFlow::Continue
    });
}

fn read() -> Option<String> {
    let out = Command::new("wl-paste")
        .args(["--no-newline", "--type", "text/plain"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    String::from_utf8(out.stdout).ok()
}

/// Copy text back to the clipboard.
pub fn copy(text: &str) {
    if let Ok(mut child) = Command::new("wl-copy").stdin(Stdio::piped()).spawn() {
        if let Some(stdin) = child.stdin.as_mut() {
            let _ = stdin.write_all(text.as_bytes());
        }
        let _ = child.wait();
    }
}
