//! Cursor/scroll interaction: hover-to-expand with a collapse debounce, plus
//! swipe-to-change-track.
//!
//! Mirror of the macOS `NotchInteractionMonitor`. On GTK we use event
//! controllers (motion + scroll) instead of polling the cursor — they're already
//! event-driven and scoped to the widget.

use std::cell::RefCell;
use std::rc::Rc;
use std::time::Duration;

use gtk::glib;
use gtk::glib::clone;
use gtk::prelude::*;

use crate::geometry::{COLLAPSE_DEBOUNCE_MS, SWIPE_THRESHOLD};

/// Callbacks the controller wires up — semantic intents, not GTK details.
pub struct Handlers {
    pub on_expand: Box<dyn Fn()>,
    pub on_collapse: Box<dyn Fn()>,
    pub on_next: Box<dyn Fn()>,
    pub on_previous: Box<dyn Fn()>,
}

/// Attach hover (expand/collapse with debounce), horizontal scroll (swipe), and —
/// in click mode — a click-to-open gesture. In click mode hover does not expand.
pub fn attach(widget: &gtk::Box, handlers: Handlers, click_mode: bool) {
    let handlers = Rc::new(handlers);
    attach_hover(widget, handlers.clone(), click_mode);
    attach_swipe(widget, handlers.clone());
    if click_mode {
        let click = gtk::GestureClick::new();
        click.connect_pressed(clone!(@strong handlers => move |_, _, _, _| (handlers.on_expand)()));
        widget.add_controller(click);
    }
}

fn attach_hover(widget: &gtk::Box, handlers: Rc<Handlers>, click_mode: bool) {
    // Holds the pending collapse timer so re-entry can cancel it.
    let collapse_src: Rc<RefCell<Option<glib::SourceId>>> = Rc::new(RefCell::new(None));
    let motion = gtk::EventControllerMotion::new();

    motion.connect_enter(clone!(
        @strong handlers, @strong collapse_src => move |_, _, _| {
            if let Some(id) = collapse_src.borrow_mut().take() {
                id.remove();
            }
            // Hover-open only in hover mode; in click mode the tap opens it.
            if !click_mode {
                (handlers.on_expand)();
            }
        }
    ));

    motion.connect_leave(clone!(
        @strong handlers, @strong collapse_src => move |_| {
            let handlers = handlers.clone();
            let slot = collapse_src.clone();
            let id = glib::timeout_add_local_once(
                Duration::from_millis(COLLAPSE_DEBOUNCE_MS),
                move || {
                    *slot.borrow_mut() = None;
                    (handlers.on_collapse)();
                },
            );
            *collapse_src.borrow_mut() = Some(id);
        }
    ));

    widget.add_controller(motion);
}

fn attach_swipe(widget: &gtk::Box, handlers: Rc<Handlers>) {
    let accum = Rc::new(RefCell::new(0.0_f64));
    let armed = Rc::new(RefCell::new(true));
    let scroll = gtk::EventControllerScroll::new(gtk::EventControllerScrollFlags::HORIZONTAL);

    scroll.connect_scroll(clone!(
        @strong handlers, @strong accum, @strong armed => move |_, dx, _dy| {
            *accum.borrow_mut() += dx;
            let total = *accum.borrow();
            if *armed.borrow() && total.abs() > SWIPE_THRESHOLD {
                *armed.borrow_mut() = false;
                // Natural scroll: swiping right (negative dx) → previous.
                if total < 0.0 { (handlers.on_previous)(); } else { (handlers.on_next)(); }
            }
            glib::Propagation::Proceed
        }
    ));

    // Reset arming when the gesture ends.
    scroll.connect_decelerate(clone!(@strong accum, @strong armed => move |_, _, _| {
        *accum.borrow_mut() = 0.0;
        *armed.borrow_mut() = true;
    }));

    widget.add_controller(scroll);
}
