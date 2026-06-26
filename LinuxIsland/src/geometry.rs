//! Sizing + placement constants.
//!
//! Mirror of the macOS `NotchGeometry` layer. On Wayland we don't compute
//! absolute screen rects — the compositor centers a top-anchored layer-shell
//! surface for us — so this is mostly logical sizes plus the drag offset that
//! becomes a layer-shell margin.

/// Collapsed pill (CSS `min-width`/`min-height` enforce these visually).
pub const COLLAPSED_WIDTH: i32 = 200;
pub const COLLAPSED_HEIGHT: i32 = 32;

/// Expanded island.
pub const EXPANDED_WIDTH: i32 = 420;
pub const EXPANDED_HEIGHT: i32 = 200;

/// How long the cursor must be gone before the island collapses (matches macOS).
pub const COLLAPSE_DEBOUNCE_MS: u64 = 180;

/// Horizontal scroll accumulation needed to fire a swipe (matches macOS).
pub const SWIPE_THRESHOLD: f64 = 50.0;

/// Top margin from the screen edge; a custom drag offset is added on top.
pub const BASE_TOP_MARGIN: i32 = 0;
