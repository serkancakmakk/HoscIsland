//! Desktop-notification banner: eavesdrop `org.freedesktop.Notifications.Notify`
//! calls via a D-Bus monitor and surface the sender + text.
//!
//! Linux equivalent of the macOS `NotificationWatcher` (which read the
//! Notification Center SQLite DB). Becoming a monitor needs a dedicated
//! connection, so we open our own session bus just for snooping.

use std::collections::HashMap;

use futures_util::StreamExt;
use gtk::glib;
use zbus::zvariant::OwnedValue;
use zbus::{Connection, MessageStream};

use crate::model::Notification;

/// `Notify` argument tuple: (app_name, replaces_id, app_icon, summary, body,
/// actions, hints, expire_timeout).
type NotifyArgs = (
    String,
    u32,
    String,
    String,
    String,
    Vec<String>,
    HashMap<String, OwnedValue>,
    i32,
);

/// Start monitoring; `on_notify` fires (on the UI thread) for each notification.
pub fn start<F: Fn(Notification) + 'static>(on_notify: F) {
    glib::spawn_future_local(async move {
        if let Err(e) = run(on_notify).await {
            eprintln!("[notifications] stopped: {e}");
        }
    });
}

async fn run<F: Fn(Notification) + 'static>(on_notify: F) -> zbus::Result<()> {
    let conn = Connection::session().await?;
    let monitor = zbus::fdo::MonitoringProxy::builder(&conn)
        .destination("org.freedesktop.DBus")?
        .path("/org/freedesktop/DBus")?
        .build()
        .await?;
    let rule = zbus::MatchRule::try_from(
        "type='method_call',interface='org.freedesktop.Notifications',member='Notify'",
    )?;
    monitor.become_monitor(&[rule], 0).await?;

    let mut stream = MessageStream::from(conn);
    while let Some(msg) = stream.next().await {
        let Ok(msg) = msg else { continue };
        if let Ok(args) = msg.body().deserialize::<NotifyArgs>() {
            let (app, _, _, summary, body, ..) = args;
            on_notify(Notification { app, summary, body });
        }
    }
    Ok(())
}
