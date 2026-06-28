//! Open-windows switcher for wlroots compositors (Hyprland / Sway).
//!
//! Mirror of the macOS `WindowsManager`. There's no portable Wayland API for
//! listing toplevels, so we shell out to the compositor's CLI (`hyprctl` /
//! `swaymsg`) and focus by id.

use std::process::Command;
use std::time::Duration;

use gtk::glib;
use serde::Deserialize;

#[derive(Clone, Debug)]
pub struct Win {
    pub id: String,   // hyprland address / sway con_id
    pub app: String,
    pub title: String,
}

enum Compositor {
    Hyprland,
    Sway,
    None,
}

fn detect() -> Compositor {
    if std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some() {
        Compositor::Hyprland
    } else if std::env::var_os("SWAYSOCK").is_some() {
        Compositor::Sway
    } else {
        Compositor::None
    }
}

/// Poll the window list every 2s; `on_update` runs on the UI thread.
pub fn start<F: Fn(Vec<Win>) + 'static>(on_update: F) {
    glib::timeout_add_local(Duration::from_secs(2), move || {
        on_update(list());
        glib::ControlFlow::Continue
    });
}

pub fn focus(id: &str) {
    match detect() {
        Compositor::Hyprland => {
            let _ = Command::new("hyprctl")
                .args(["dispatch", "focuswindow", &format!("address:{id}")])
                .spawn();
        }
        Compositor::Sway => {
            let _ = Command::new("swaymsg").arg(format!("[con_id={id}] focus")).spawn();
        }
        Compositor::None => {}
    }
}

/// Close a window by compositor id.
pub fn close(id: &str) {
    match detect() {
        Compositor::Hyprland => {
            let _ = Command::new("hyprctl")
                .args(["dispatch", "closewindow", &format!("address:{id}")])
                .spawn();
        }
        Compositor::Sway => {
            let _ = Command::new("swaymsg").arg(format!("[con_id={id}] kill")).spawn();
        }
        Compositor::None => {}
    }
}

fn list() -> Vec<Win> {
    match detect() {
        Compositor::Hyprland => hyprland().unwrap_or_default(),
        Compositor::Sway => sway().unwrap_or_default(),
        Compositor::None => Vec::new(),
    }
}

// --- Hyprland ---

#[derive(Deserialize)]
struct HyprClient {
    address: String,
    class: String,
    title: String,
    mapped: bool,
    hidden: bool,
}

fn hyprland() -> Option<Vec<Win>> {
    let out = Command::new("hyprctl").args(["clients", "-j"]).output().ok()?;
    let clients: Vec<HyprClient> = serde_json::from_slice(&out.stdout).ok()?;
    Some(
        clients
            .into_iter()
            .filter(|c| c.mapped && !c.hidden && !c.title.is_empty())
            .map(|c| Win { id: c.address, app: c.class, title: c.title })
            .take(12)
            .collect(),
    )
}

// --- Sway ---

#[derive(Deserialize)]
struct SwayNode {
    id: i64,
    name: Option<String>,
    app_id: Option<String>,
    #[serde(default)]
    window_properties: Option<WindowProps>,
    #[serde(default)]
    nodes: Vec<SwayNode>,
    #[serde(default)]
    floating_nodes: Vec<SwayNode>,
}

#[derive(Deserialize)]
struct WindowProps {
    class: Option<String>,
}

fn sway() -> Option<Vec<Win>> {
    let out = Command::new("swaymsg").args(["-t", "get_tree"]).output().ok()?;
    let root: SwayNode = serde_json::from_slice(&out.stdout).ok()?;
    let mut acc = Vec::new();
    collect(&root, &mut acc);
    acc.truncate(12);
    Some(acc)
}

fn collect(node: &SwayNode, acc: &mut Vec<Win>) {
    let app = node
        .app_id
        .clone()
        .or_else(|| node.window_properties.as_ref().and_then(|w| w.class.clone()));
    if let (Some(app), Some(title)) = (app, node.name.clone()) {
        if !title.is_empty() {
            acc.push(Win { id: node.id.to_string(), app, title });
        }
    }
    for child in node.nodes.iter().chain(node.floating_nodes.iter()) {
        collect(child, acc);
    }
}
