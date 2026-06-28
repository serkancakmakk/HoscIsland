//! Current weather with no API key: IP geolocation (ipapi.co) → Open-Meteo.
//! Mirror of the macOS `WeatherManager`. Refreshes every 30 minutes.

use std::thread;
use std::time::Duration;

use gtk::glib;
use serde::Deserialize;

pub struct Weather {
    pub temp_c: i32,
    pub feels_like: i32,
    pub hi: i32,
    pub lo: i32,
    pub code: i32, // WMO weather code
    pub city: String,
}

#[derive(Deserialize)]
struct IpLoc {
    latitude: f64,
    longitude: f64,
    city: String,
}

#[derive(Deserialize)]
struct Meteo {
    current: Current,
    daily: Option<Daily>,
}

#[derive(Deserialize)]
struct Current {
    temperature_2m: f64,
    weather_code: i32,
    apparent_temperature: Option<f64>,
}

#[derive(Deserialize)]
struct Daily {
    temperature_2m_max: Vec<f64>,
    temperature_2m_min: Vec<f64>,
}

pub fn start<F: Fn(Weather) + 'static>(on_update: F) {
    let (tx, rx) = async_channel::unbounded::<Weather>();

    thread::spawn(move || loop {
        if let Some(w) = fetch() {
            let _ = tx.send_blocking(w);
        }
        thread::sleep(Duration::from_secs(1800));
    });

    glib::spawn_future_local(async move {
        while let Ok(w) = rx.recv().await {
            on_update(w);
        }
    });
}

fn fetch() -> Option<Weather> {
    let loc: IpLoc = get("https://ipapi.co/json/")?;
    let url = format!(
        "https://api.open-meteo.com/v1/forecast?latitude={}&longitude={}\
         &current=temperature_2m,weather_code,apparent_temperature\
         &daily=temperature_2m_max,temperature_2m_min&forecast_days=1&timezone=auto",
        loc.latitude, loc.longitude
    );
    let m: Meteo = get(&url)?;
    let temp = m.current.temperature_2m;
    let feels = m.current.apparent_temperature.unwrap_or(temp);
    let hi = m.daily.as_ref().and_then(|d| d.temperature_2m_max.first().copied()).unwrap_or(temp);
    let lo = m.daily.as_ref().and_then(|d| d.temperature_2m_min.first().copied()).unwrap_or(temp);
    Some(Weather {
        temp_c: temp.round() as i32,
        feels_like: feels.round() as i32,
        hi: hi.round() as i32,
        lo: lo.round() as i32,
        code: m.current.weather_code,
        city: loc.city,
    })
}

fn get<T: serde::de::DeserializeOwned>(url: &str) -> Option<T> {
    let body = ureq::get(url)
        .timeout(Duration::from_secs(20))
        .call()
        .ok()?
        .into_string()
        .ok()?;
    serde_json::from_str(&body).ok()
}

/// Map a WMO weather code to a themed icon name.
pub fn icon_name(code: i32) -> &'static str {
    match code {
        0 => "weather-clear-symbolic",
        1 | 2 => "weather-few-clouds-symbolic",
        3 => "weather-overcast-symbolic",
        45 | 48 => "weather-fog-symbolic",
        51..=67 | 80..=82 => "weather-showers-symbolic",
        71..=77 | 85 | 86 => "weather-snow-symbolic",
        95..=99 => "weather-storm-symbolic",
        _ => "weather-overcast-symbolic",
    }
}
