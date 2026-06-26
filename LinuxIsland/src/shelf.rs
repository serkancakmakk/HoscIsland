//! Persistent file shelf — paths dropped onto the island.
//!
//! Mirror of the macOS `ShelfStore` (which used UserDefaults). Persisted as a
//! newline-delimited list at `~/.config/linux-island/shelf`.

use std::fs;
use std::path::{Path, PathBuf};

#[derive(Default)]
pub struct ShelfStore {
    items: Vec<PathBuf>,
}

impl ShelfStore {
    pub fn load() -> Self {
        let items = Self::path()
            .and_then(|p| fs::read_to_string(p).ok())
            .map(|s| {
                s.lines()
                    .filter(|l| !l.trim().is_empty())
                    .map(PathBuf::from)
                    .filter(|p| p.exists())
                    .collect()
            })
            .unwrap_or_default();
        Self { items }
    }

    pub fn items(&self) -> &[PathBuf] {
        &self.items
    }

    pub fn add(&mut self, path: PathBuf) {
        if !self.items.contains(&path) {
            self.items.push(path);
            self.save();
        }
    }

    pub fn remove(&mut self, path: &Path) {
        self.items.retain(|p| p != path);
        self.save();
    }

    pub fn clear(&mut self) {
        self.items.clear();
        self.save();
    }

    fn path() -> Option<PathBuf> {
        let base = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))?;
        Some(base.join("linux-island").join("shelf"))
    }

    fn save(&self) {
        let Some(p) = Self::path() else { return };
        if let Some(dir) = p.parent() {
            let _ = fs::create_dir_all(dir);
        }
        let body: String = self
            .items
            .iter()
            .map(|p| p.to_string_lossy().into_owned())
            .collect::<Vec<_>>()
            .join("\n");
        let _ = fs::write(p, body);
    }
}
