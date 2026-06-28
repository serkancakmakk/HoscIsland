//! Tiny localization helper. The language is resolved once at startup (Linux
//! applies UI settings on the next launch anyway), stored in a global, and read
//! by `t(tr, en)` at every call site — mirror of the macOS `L(tr, en)` helper.

use std::sync::OnceLock;

static ENGLISH: OnceLock<bool> = OnceLock::new();

/// Set the resolved language once, at startup.
pub fn init(english: bool) {
    let _ = ENGLISH.set(english);
}

fn english() -> bool {
    *ENGLISH.get().unwrap_or(&false)
}

/// Pick the Turkish or English string for the current UI language.
pub fn t<'a>(tr: &'a str, en: &'a str) -> &'a str {
    if english() { en } else { tr }
}
