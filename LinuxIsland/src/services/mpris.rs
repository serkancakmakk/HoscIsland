//! Now-playing + transport controls over MPRIS (`org.mpris.MediaPlayer2`).
//!
//! Linux equivalent of the macOS `NowPlayingManager`. Covers metadata, transport,
//! progress + seek, shuffle/repeat, and raise — for any MPRIS-compliant player
//! (not just Music/Spotify). Runs on the GTK main context via
//! `glib::spawn_future_local`, so callbacks fire on the UI thread.

use std::collections::HashMap;
use std::rc::Rc;
use std::time::Duration;

use futures_util::StreamExt;
use gtk::glib;
use zbus::zvariant::{ObjectPath, OwnedValue};
use zbus::{proxy, Connection};

use crate::model::Track;

/// Transport commands the UI can issue.
#[derive(Clone, Debug)]
pub enum Command {
    Next,
    Previous,
    PlayPause,
    Raise,
    ToggleShuffle,
    CycleLoop,
    SetPosition { track_id: String, position_us: i64 },
}

/// Cheap cloneable handle the UI keeps to drive playback.
#[derive(Clone)]
pub struct Controls(async_channel::Sender<Command>);

impl Controls {
    pub fn next(&self) { self.send(Command::Next); }
    pub fn previous(&self) { self.send(Command::Previous); }
    pub fn play_pause(&self) { self.send(Command::PlayPause); }
    pub fn raise(&self) { self.send(Command::Raise); }
    pub fn toggle_shuffle(&self) { self.send(Command::ToggleShuffle); }
    pub fn cycle_loop(&self) { self.send(Command::CycleLoop); }
    pub fn set_position(&self, track_id: String, position_us: i64) {
        self.send(Command::SetPosition { track_id, position_us });
    }
    fn send(&self, c: Command) { let _ = self.0.try_send(c); }
}

/// Progress update: (position µs, length µs).
pub type Progress = (i64, i64);

#[proxy(
    interface = "org.mpris.MediaPlayer2.Player",
    default_path = "/org/mpris/MediaPlayer2"
)]
trait Player {
    fn next(&self) -> zbus::Result<()>;
    fn previous(&self) -> zbus::Result<()>;
    fn play_pause(&self) -> zbus::Result<()>;
    fn set_position(&self, track_id: &ObjectPath<'_>, position: i64) -> zbus::Result<()>;

    #[zbus(property)]
    fn playback_status(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn position(&self) -> zbus::Result<i64>;
    #[zbus(property)]
    fn metadata(&self) -> zbus::Result<HashMap<String, OwnedValue>>;
    #[zbus(property)]
    fn shuffle(&self) -> zbus::Result<bool>;
    #[zbus(property)]
    fn set_shuffle(&self, value: bool) -> zbus::Result<()>;
    #[zbus(property)]
    fn loop_status(&self) -> zbus::Result<String>;
    #[zbus(property)]
    fn set_loop_status(&self, value: &str) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.mpris.MediaPlayer2",
    default_path = "/org/mpris/MediaPlayer2"
)]
trait MediaPlayer2 {
    fn raise(&self) -> zbus::Result<()>;
}

/// Create the command channel + a `Controls` handle. Pair with [`start`].
pub fn channel() -> (Controls, async_channel::Receiver<Command>) {
    let (tx, rx) = async_channel::unbounded();
    (Controls(tx), rx)
}

/// Spawn the MPRIS task. `on_track` fires on track/state change; `on_progress`
/// fires roughly once a second while playing.
pub fn start<T, P>(rx: async_channel::Receiver<Command>, on_track: T, on_progress: P)
where
    T: Fn(Option<Track>) + 'static,
    P: Fn(Progress) + 'static,
{
    glib::spawn_future_local(async move {
        if let Err(e) = run(rx, on_track, on_progress).await {
            eprintln!("[mpris] stopped: {e}");
        }
    });
}

async fn run<T, P>(
    rx: async_channel::Receiver<Command>,
    on_track: T,
    on_progress: P,
) -> zbus::Result<()>
where
    T: Fn(Option<Track>) + 'static,
    P: Fn(Progress) + 'static,
{
    let conn = Connection::session().await?;
    let (player, name) = wait_for_player(&conn).await?;
    let base = MediaPlayer2Proxy::builder(&conn).destination(name)?.build().await?;

    let on_track: Rc<dyn Fn(Option<Track>)> = Rc::new(on_track);
    (*on_track)(track_from(&player).await);

    // Transport commands.
    let cmd_player = player.clone();
    glib::spawn_future_local(async move {
        while let Ok(cmd) = rx.recv().await {
            let _ = handle_command(&cmd_player, &base, cmd).await;
        }
    });

    // Progress poll (~1s).
    let prog_player = player.clone();
    glib::spawn_future_local(async move {
        loop {
            if prog_player.playback_status().await.as_deref() == Ok("Playing") {
                if let (Ok(pos), Ok(meta)) =
                    (prog_player.position().await, prog_player.metadata().await)
                {
                    on_progress((pos, length_us(&meta)));
                }
            }
            glib::timeout_future(Duration::from_secs(1)).await;
        }
    });

    // Metadata changes.
    let meta_player = player.clone();
    let meta_cb = on_track.clone();
    glib::spawn_future_local(async move {
        let mut stream = meta_player.receive_metadata_changed().await;
        while stream.next().await.is_some() {
            (*meta_cb)(track_from(&meta_player).await);
        }
    });

    // Playback-status changes (play/pause icon).
    let mut status = player.receive_playback_status_changed().await;
    while status.next().await.is_some() {
        (*on_track)(track_from(&player).await);
    }
    Ok(())
}

async fn handle_command(
    player: &PlayerProxy<'_>,
    base: &MediaPlayer2Proxy<'_>,
    cmd: Command,
) -> zbus::Result<()> {
    match cmd {
        Command::Next => player.next().await,
        Command::Previous => player.previous().await,
        Command::PlayPause => player.play_pause().await,
        Command::Raise => base.raise().await,
        Command::ToggleShuffle => {
            let cur = player.shuffle().await.unwrap_or(false);
            player.set_shuffle(!cur).await
        }
        Command::CycleLoop => {
            let next = match player.loop_status().await.as_deref() {
                Ok("None") => "Playlist",
                Ok("Playlist") => "Track",
                _ => "None",
            };
            player.set_loop_status(next).await
        }
        Command::SetPosition { track_id, position_us } => {
            match ObjectPath::try_from(track_id) {
                Ok(path) => player.set_position(&path, position_us).await,
                Err(_) => Ok(()),
            }
        }
    }
}

/// Poll the bus until a player shows up; return its proxy and bus name.
async fn wait_for_player(conn: &Connection) -> zbus::Result<(PlayerProxy<'static>, String)> {
    loop {
        let dbus = zbus::fdo::DBusProxy::new(conn).await?;
        let player = dbus
            .list_names()
            .await?
            .into_iter()
            .map(|n| n.to_string())
            .find(|n| n.starts_with("org.mpris.MediaPlayer2."));

        if let Some(name) = player {
            let proxy = PlayerProxy::builder(conn).destination(name.clone())?.build().await?;
            return Ok((proxy, name));
        }
        glib::timeout_future(Duration::from_secs(2)).await;
    }
}

async fn track_from(proxy: &PlayerProxy<'_>) -> Option<Track> {
    let meta = proxy.metadata().await.ok()?;
    let title = string_value(&meta, "xesam:title").unwrap_or_default();
    let artist = first_string_value(&meta, "xesam:artist").unwrap_or_default();
    if title.is_empty() && artist.is_empty() {
        return None;
    }
    let playing = proxy.playback_status().await.ok().as_deref() == Some("Playing");
    Some(Track {
        title,
        artist,
        album: string_value(&meta, "xesam:album").unwrap_or_default(),
        art_url: string_value(&meta, "mpris:artUrl"),
        track_id: string_value(&meta, "mpris:trackid").unwrap_or_default(),
        length_us: length_us(&meta),
        playing,
        shuffle: proxy.shuffle().await.unwrap_or(false),
        loop_status: proxy.loop_status().await.unwrap_or_default(),
    })
}

fn length_us(meta: &HashMap<String, OwnedValue>) -> i64 {
    meta.get("mpris:length")
        .and_then(|v| i64::try_from(v.clone()).ok())
        .unwrap_or(0)
}

fn string_value(meta: &HashMap<String, OwnedValue>, key: &str) -> Option<String> {
    meta.get(key).and_then(|v| String::try_from(v.clone()).ok())
}

fn first_string_value(meta: &HashMap<String, OwnedValue>, key: &str) -> Option<String> {
    let list = meta.get(key)?;
    Vec::<String>::try_from(list.clone()).ok()?.into_iter().next()
}
