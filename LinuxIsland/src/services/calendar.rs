//! Next calendar event from an iCalendar (.ics) feed URL.
//!
//! Mirror of the macOS `CalendarManager`. Fetches the user's private iCal URL
//! (Google/iCloud/Outlook all expose one), parses VEVENTs, and surfaces the
//! soonest upcoming event as `(title, when)`. Refreshes every 15 minutes.

use std::thread;
use std::time::Duration;

use gtk::glib;

/// `on_update` fires (on the UI thread) with the next event, or `None`.
pub fn start<F: Fn(Option<(String, String)>) + 'static>(url: String, on_update: F) {
    let (tx, rx) = async_channel::unbounded::<Option<(String, String)>>();

    thread::spawn(move || loop {
        let next = fetch(&url).and_then(|ics| next_event(&ics));
        let _ = tx.send_blocking(next);
        thread::sleep(Duration::from_secs(900));
    });

    glib::spawn_future_local(async move {
        while let Ok(ev) = rx.recv().await {
            on_update(ev);
        }
    });
}

fn fetch(url: &str) -> Option<String> {
    ureq::get(url)
        .timeout(Duration::from_secs(20))
        .call()
        .ok()?
        .into_string()
        .ok()
}

/// Parse the ICS and return the soonest `(title, when)` from now.
fn next_event(ics: &str) -> Option<(String, String)> {
    let lines = unfold(ics);
    let now = glib::DateTime::now_local().ok()?;
    let now_unix = now.to_unix();

    let mut best: Option<(i64, String)> = None;
    let mut in_event = false;
    let mut summary = String::new();
    let mut start: Option<glib::DateTime> = None;
    let mut all_day = false;

    for line in lines {
        if line == "BEGIN:VEVENT" {
            in_event = true;
            summary.clear();
            start = None;
            all_day = false;
        } else if line == "END:VEVENT" {
            if let (Some(dt), false) = (&start, summary.is_empty()) {
                let ts = dt.to_unix();
                // All-day: keep if today or later; timed: keep if in the future.
                let keep = if all_day { ts + 86_400 >= now_unix } else { ts >= now_unix };
                if keep && best.as_ref().map_or(true, |(bts, _)| ts < *bts) {
                    let when = format_when(dt, &now, all_day);
                    best = Some((ts, format!("{summary}\u{0}{when}")));
                }
            }
            in_event = false;
        } else if in_event {
            if line.starts_with("SUMMARY") {
                summary = value_of(&line);
            } else if line.starts_with("DTSTART") {
                let (dt, is_date) = parse_date(&line);
                start = dt;
                all_day = is_date;
            }
        }
    }

    best.map(|(_, packed)| {
        let mut parts = packed.splitn(2, '\u{0}');
        (
            parts.next().unwrap_or_default().to_owned(),
            parts.next().unwrap_or_default().to_owned(),
        )
    })
}

/// RFC 5545 line unfolding (continuation lines start with space/tab).
fn unfold(ics: &str) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for raw in ics.replace("\r\n", "\n").split('\n') {
        if (raw.starts_with(' ') || raw.starts_with('\t')) && !out.is_empty() {
            let last = out.last_mut().unwrap();
            last.push_str(&raw[1..]);
        } else {
            out.push(raw.to_owned());
        }
    }
    out
}

/// Value after the first colon, with common ICS escapes undone.
fn value_of(line: &str) -> String {
    match line.find(':') {
        Some(i) => line[i + 1..]
            .replace("\\,", ",")
            .replace("\\;", ";")
            .replace("\\n", " ")
            .trim()
            .to_owned(),
        None => String::new(),
    }
}

/// Parse a `DTSTART…` line into a `DateTime` and whether it's an all-day DATE.
fn parse_date(line: &str) -> (Option<glib::DateTime>, bool) {
    let raw = value_of(line);
    let is_date = line.to_uppercase().contains("VALUE=DATE") || (raw.len() == 8 && !raw.contains('T'));

    let digits: Vec<char> = raw.chars().filter(|c| c.is_ascii_digit()).collect();
    let num = |a: usize, b: usize| -> i32 {
        digits.get(a..b).map(|s| s.iter().collect::<String>().parse().unwrap_or(0)).unwrap_or(0)
    };
    if digits.len() < 8 {
        return (None, is_date);
    }
    let (y, mo, d) = (num(0, 4), num(4, 6), num(6, 8));

    if is_date {
        return (glib::DateTime::from_local(y, mo, d, 0, 0, 0.0).ok(), true);
    }
    let (h, mi, s) = (num(8, 10), num(10, 12), num(12, 14));
    let dt = if raw.ends_with('Z') {
        glib::DateTime::from_utc(y, mo, d, h, mi, s as f64)
            .ok()
            .and_then(|u| u.to_local().ok())
    } else {
        glib::DateTime::from_local(y, mo, d, h, mi, s as f64).ok()
    };
    (dt, false)
}

/// "Bugün", "Yarın 09:00", "14:30", or "5 Tem 09:00". Built manually so it
/// doesn't depend on glib's strftime extensions or the system locale.
fn format_when(dt: &glib::DateTime, now: &glib::DateTime, all_day: bool) -> String {
    const MONTHS: [&str; 12] = [
        "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara",
    ];
    let same_day = dt.year() == now.year() && dt.day_of_year() == now.day_of_year();
    let tomorrow = dt.year() == now.year() && dt.day_of_year() == now.day_of_year() + 1;
    let time = format!("{:02}:{:02}", dt.hour(), dt.minute());
    let month = MONTHS.get((dt.month() - 1).clamp(0, 11) as usize).copied().unwrap_or("");
    let date = format!("{} {}", dt.day_of_month(), month);

    if all_day {
        if same_day {
            "Bugün".to_owned()
        } else if tomorrow {
            "Yarın".to_owned()
        } else {
            date
        }
    } else if same_day {
        time
    } else if tomorrow {
        format!("Yarın {time}")
    } else {
        format!("{date} {time}")
    }
}
