//! Gmail unread reader via the account's Atom feed
//! (`https://mail.google.com/mail/feed/atom`) with HTTP Basic auth (email + an
//! **App Password**). Mirror of the macOS `GmailManager`.
//!
//! Blocking HTTP runs on a background thread; results are bounced to the GTK main
//! context over an async channel. Only unread headers are read, never bodies.

use std::collections::HashSet;
use std::thread;
use std::time::Duration;

use base64::Engine;
use gtk::glib;
use quick_xml::events::Event;
use quick_xml::name::QName;
use quick_xml::Reader;

#[derive(Clone, Debug)]
pub struct Mail {
    pub author: String,
    pub title: String,
    pub link: String,
}

pub struct Update {
    pub unread: u32,
    pub messages: Vec<Mail>,
    /// Genuinely new messages since the last poll (empty on the first fetch).
    pub new: Vec<Mail>,
}

/// Start polling every 60s. `on_update` runs on the UI thread.
pub fn start<F: Fn(Update) + 'static>(email: String, password: String, on_update: F) {
    let (tx, rx) = async_channel::unbounded::<Update>();

    thread::spawn(move || {
        let mut seen: HashSet<String> = HashSet::new();
        let mut first = true;
        loop {
            if let Some((unread, messages)) = fetch(&email, &password) {
                let mut new = Vec::new();
                for m in &messages {
                    let key = format!("{}|{}", m.author, m.title);
                    if seen.insert(key) && !first {
                        new.push(m.clone());
                    }
                }
                let _ = tx.send_blocking(Update { unread, messages, new });
                first = false;
            }
            thread::sleep(Duration::from_secs(60));
        }
    });

    glib::spawn_future_local(async move {
        while let Ok(update) = rx.recv().await {
            on_update(update);
        }
    });
}

fn fetch(email: &str, password: &str) -> Option<(u32, Vec<Mail>)> {
    let auth = base64::engine::general_purpose::STANDARD.encode(format!("{email}:{password}"));
    let resp = ureq::get("https://mail.google.com/mail/feed/atom")
        .set("Authorization", &format!("Basic {auth}"))
        .timeout(Duration::from_secs(20))
        .call()
        .ok()?;
    let body = resp.into_string().ok()?;
    Some(parse(&body))
}

fn parse(xml: &str) -> (u32, Vec<Mail>) {
    let mut reader = Reader::from_str(xml);
    let mut buf = Vec::new();
    let mut messages = Vec::new();
    let mut fullcount = 0u32;

    let mut in_entry = false;
    let mut text = String::new();
    let (mut title, mut author, mut link) = (String::new(), String::new(), String::new());

    loop {
        match reader.read_event_into(&mut buf) {
            Ok(Event::Start(e)) => {
                let name = local(&e.name());
                text.clear();
                if name == "entry" {
                    in_entry = true;
                    title.clear();
                    author.clear();
                    link.clear();
                } else if name == "link" && in_entry {
                    for attr in e.attributes().flatten() {
                        if attr.key.as_ref() == b"href" {
                            link = String::from_utf8_lossy(&attr.value).into_owned();
                        }
                    }
                }
            }
            Ok(Event::Text(e)) => {
                if let Ok(t) = e.unescape() {
                    text.push_str(&t);
                }
            }
            Ok(Event::End(e)) => {
                let name = local(&e.name());
                let value = text.trim().to_string();
                if name == "fullcount" && !in_entry {
                    fullcount = value.parse().unwrap_or(0);
                } else if in_entry {
                    match name.as_str() {
                        "title" => title = value,
                        "name" => author = value,
                        "entry" => {
                            messages.push(Mail {
                                author: if author.is_empty() { "Gmail".into() } else { author.clone() },
                                title: if title.is_empty() { "(konu yok)".into() } else { title.clone() },
                                link: link.clone(),
                            });
                            in_entry = false;
                        }
                        _ => {}
                    }
                }
                text.clear();
            }
            Ok(Event::Eof) | Err(_) => break,
            _ => {}
        }
        buf.clear();
    }
    (fullcount, messages)
}

fn local(name: &QName) -> String {
    String::from_utf8_lossy(name.local_name().as_ref()).into_owned()
}
