import AppKit

/// Watches the cursor and scroll/click events to drive open/close and
/// swipe-to-change-track, *without* capturing events.
///
/// We poll the cursor position instead of using tracking areas because a
/// tracking area requires the window to capture mouse events, which would block
/// clicks to the menu bar sitting under the collapsed pill. Polling — plus
/// non-consuming global/local event monitors — lets the collapsed window stay
/// fully click-through (`ignoresMouseEvents = true`).
final class NotchInteractionMonitor {
    /// Live geometry/state queried each tick (owned by the controller).
    struct Context {
        var collapsedZone: () -> NSRect?
        var expandedZone: () -> NSRect?
        var isExpanded: () -> Bool
        var screenshotActive: () -> Bool
        var hasTrack: () -> Bool
    }

    /// Intents emitted back to the controller.
    var onSetExpanded: (Bool) -> Void = { _ in }
    var onHoverChange: (Bool) -> Void = { _ in }
    var onNext: () -> Void = {}
    var onPrevious: () -> Void = {}

    private let context: Context
    private var hoverTimer: Timer?
    private var collapseWorkItem: DispatchWorkItem?
    private var eventMonitors: [Any] = []

    private var swipeAccum: CGFloat = 0
    private var swipeArmed = true
    private var lastHover = false

    private var clickMode: Bool { Settings.shared.interactionMode == .click }

    init(context: Context) { self.context = context }

    func start() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            self?.checkHover()
        }
        startEventMonitors()
    }

    // MARK: - Event monitors (non-consuming)

    private func startEventMonitors() {
        let scroll: (NSEvent) -> Void = { [weak self] e in self?.handleScroll(e) }
        // Global monitor sees scrolls headed to other apps (over the notch) without
        // consuming them; local monitor covers scrolls over our own window.
        addGlobal(.scrollWheel) { scroll($0) }
        addLocal(.scrollWheel) { scroll($0); return $0 }

        // Click-to-open: non-consuming monitors so the notch stays passthrough.
        addGlobal(.leftMouseDown) { [weak self] _ in self?.handleClick() }
        addLocal(.leftMouseDown) { [weak self] e in self?.handleClick(); return e }
    }

    private func addGlobal(_ mask: NSEvent.EventTypeMask, _ handler: @escaping (NSEvent) -> Void) {
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) {
            eventMonitors.append(m)
        }
    }

    private func addLocal(_ mask: NSEvent.EventTypeMask, _ handler: @escaping (NSEvent) -> NSEvent?) {
        if let m = NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler) {
            eventMonitors.append(m)
        }
    }

    // MARK: - Click

    private func handleClick() {
        guard clickMode, !context.isExpanded(), !context.screenshotActive(),
              let zone = context.collapsedZone() else { return }
        if zone.contains(NSEvent.mouseLocation) { onSetExpanded(true) }
    }

    // MARK: - Swipe-to-change-track

    private func handleScroll(_ event: NSEvent) {
        guard context.hasTrack() else { return }
        let zone = context.isExpanded() ? context.expandedZone() : context.collapsedZone()
        guard let zone, zone.contains(NSEvent.mouseLocation) else {
            swipeAccum = 0; swipeArmed = true; return
        }

        if event.phase == .began { swipeAccum = 0; swipeArmed = true }
        // Only horizontal swipes.
        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) {
            swipeAccum += event.scrollingDeltaX
        }
        if swipeArmed, abs(swipeAccum) > 50 {
            swipeArmed = false
            if swipeAccum > 0 { onPrevious() } else { onNext() }
        }
        if event.phase == .ended || event.phase == .cancelled { swipeAccum = 0; swipeArmed = true }
    }

    // MARK: - Hover poll

    private func checkHover() {
        if context.screenshotActive() { return }
        let expanded = context.isExpanded()
        guard let zone = expanded ? context.expandedZone() : context.collapsedZone() else { return }
        let inside = zone.contains(NSEvent.mouseLocation)

        // Track hover for the click-mode "nudge" (only emit on change).
        let hovering = inside && !expanded
        if hovering != lastHover { lastHover = hovering; onHoverChange(hovering) }

        if inside {
            collapseWorkItem?.cancel()
            collapseWorkItem = nil
            // Hover-open only in hover mode; in click mode the tap handles opening.
            if !expanded, !clickMode { onSetExpanded(true) }
        } else if expanded, collapseWorkItem == nil {
            let work = DispatchWorkItem { [weak self] in
                self?.onSetExpanded(false)
                self?.collapseWorkItem = nil
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
    }
}
