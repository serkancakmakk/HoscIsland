//! Time-synced lyrics from lrclib.net (no API key). Mirror of the macOS
//! `LyricsManager`. Fetches on a background thread; the parsed (seconds, text)
//! lines are handed back on the UI thread.

use std::thread;
use std::time::Duration;

use gtk::glib;
use serde::Deserialize;

#[derive(Deserialize)]
struct Resp {
    #[serde(rename = "syncedLyrics")]
    synced: Option<String>,
}

/// Fetch synced lyrics; `cb(lines)` runs on the UI thread (empty on failure).
pub fn fetch<F: FnOnce(Vec<(f64, String)>) + 'static>(
    title: String,
    artist: String,
    album: String,
    duration_secs: i64,
    cb: F,
) {
    let (tx, rx) = async_channel::bounded(1);
    thread::spawn(move || {
        let lines = do_fetch(&title, &artist, &album, duration_secs).unwrap_or_default();
        let _ = tx.send_blocking(lines);
    });
    glib::spawn_future_local(async move {
        if let Ok(lines) = rx.recv().await {
            cb(lines);
        }
    });
}

fn do_fetch(title: &str, artist: &str, album: &str, duration: i64) -> Option<Vec<(f64, String)>> {
    let body = ureq::get("https://lrclib.net/api/get")
        .query("track_name", title)
        .query("artist_name", artist)
        .query("album_name", album)
        .query("duration", &duration.to_string())
        .timeout(Duration::from_secs(20))
        .call()
        .ok()?
        .into_string()
        .ok()?;
    let resp: Resp = serde_json::from_str(&body).ok()?;
    let synced = resp.synced?;
    let lines = parse_lrc(&synced);
    if lines.is_empty() { None } else { Some(lines) }
}

fn parse_lrc(lrc: &str) -> Vec<(f64, String)> {
    let mut out = Vec::new();
    for line in lrc.lines() {
        let mut rest = line;
        let mut times = Vec::new();
        while rest.starts_with('[') {
            let Some(end) = rest.find(']') else { break };
            if let Some(t) = parse_time(&rest[1..end]) {
                times.push(t);
            }
            rest = &rest[end + 1..];
        }
        let text = rest.trim().to_string();
        for t in times {
            out.push((t, text.clone()));
        }
    }
    out.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));
    out
}

fn parse_time(tag: &str) -> Option<f64> {
    let (m, s) = tag.split_once(':')?;
    Some(m.parse::<f64>().ok()? * 60.0 + s.parse::<f64>().ok()?)
}
