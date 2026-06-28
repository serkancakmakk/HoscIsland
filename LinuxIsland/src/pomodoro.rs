//! A simple 25-minute Pomodoro countdown.
//!
//! Linux equivalent of the macOS `PomodoroTimer`. Owns a 1s glib tick while
//! running and reports the remaining time via a callback (on the UI thread).

use std::cell::{Cell, RefCell};
use std::rc::Rc;
use std::time::Duration;

use gtk::glib;

/// Selectable work lengths in minutes (tapping the timer cycles these).
const PRESETS: [u32; 4] = [15, 25, 45, 60];

#[derive(Clone)]
pub struct Pomodoro {
    remaining: Rc<Cell<u32>>,
    running: Rc<Cell<bool>>,
    /// Current work length in minutes (one of `PRESETS`).
    work_minutes: Rc<Cell<u32>>,
    /// Generation token so a restarted tick supersedes the previous one.
    generation: Rc<Cell<u64>>,
    on_change: Rc<RefCell<Option<Box<dyn Fn(u32, bool)>>>>,
}

impl Pomodoro {
    pub fn new() -> Self {
        Self {
            remaining: Rc::new(Cell::new(25 * 60)),
            running: Rc::new(Cell::new(false)),
            work_minutes: Rc::new(Cell::new(25)),
            generation: Rc::new(Cell::new(0)),
            on_change: Rc::new(RefCell::new(None)),
        }
    }

    /// Tap-to-change: jump to the next preset length and reset to it.
    pub fn cycle_duration(&self) {
        let cur = self.work_minutes.get();
        let idx = PRESETS.iter().position(|&m| m == cur).unwrap_or(1);
        let next = PRESETS[(idx + 1) % PRESETS.len()];
        self.work_minutes.set(next);
        self.running.set(false);
        self.generation.set(self.generation.get().wrapping_add(1));
        self.remaining.set(next * 60);
        self.emit();
    }

    /// Register the UI updater: `(remaining_seconds, running)`.
    pub fn on_change<F: Fn(u32, bool) + 'static>(&self, f: F) {
        *self.on_change.borrow_mut() = Some(Box::new(f));
        self.emit();
    }

    pub fn toggle(&self) {
        if self.running.get() { self.pause() } else { self.start() }
    }

    pub fn start(&self) {
        if self.running.get() || self.remaining.get() == 0 {
            return;
        }
        self.running.set(true);
        let gen = self.generation.get().wrapping_add(1);
        self.generation.set(gen);
        self.emit();

        let this = self.clone();
        glib::timeout_add_local(Duration::from_secs(1), move || {
            if !this.running.get() || this.generation.get() != gen {
                return glib::ControlFlow::Break;
            }
            let left = this.remaining.get().saturating_sub(1);
            this.remaining.set(left);
            if left == 0 {
                this.running.set(false);
            }
            this.emit();
            if left == 0 { glib::ControlFlow::Break } else { glib::ControlFlow::Continue }
        });
    }

    pub fn pause(&self) {
        self.running.set(false);
        self.emit();
    }

    pub fn reset(&self) {
        self.running.set(false);
        self.generation.set(self.generation.get().wrapping_add(1));
        self.remaining.set(self.work_minutes.get() * 60);
        self.emit();
    }

    pub fn label(&self) -> String {
        let s = self.remaining.get();
        format!("{:02}:{:02}", s / 60, s % 60)
    }

    pub fn running(&self) -> bool {
        self.running.get()
    }

    fn emit(&self) {
        if let Some(cb) = self.on_change.borrow().as_ref() {
            cb(self.remaining.get(), self.running.get());
        }
    }
}
