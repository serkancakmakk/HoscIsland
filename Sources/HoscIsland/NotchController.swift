import AppKit
import SwiftUI
import Combine

/// Top-level coordinator: owns the panel, the shared `NotchState`, and wires the
/// feature monitors (now-playing, notifications, battery, screenshots) plus the
/// interaction monitor together. Geometry lives in `NotchGeometry`, cursor/scroll
/// handling in `NotchInteractionMonitor`, models/state in `NotchModels`.
final class NotchController {
    private var panel: NSPanel!
    private var hostingView: PassthroughHostingView<AnyView>!
    private let state = NotchState()
    private let nowPlaying = NowPlayingManager()
    private let shelf = ShelfStore()
    private let pomodoro = PomodoroTimer()
    private let clipboard = ClipboardManager()
    private let gmail = GmailManager()
    private let systemMonitor = SystemMonitor()
    private var hudClearItem: DispatchWorkItem?
    private let weather = WeatherManager()
    private let windowsManager = WindowsManager()
    private let lyrics = LyricsManager()
    private var geometry = NotchGeometry(notchWidth: 200, topInset: 38)
    private var cancellables = Set<AnyCancellable>()

    private var notificationClearItem: DispatchWorkItem?
    private var batteryClearItem: DispatchWorkItem?
    private var screenshotClearItem: DispatchWorkItem?

    private let notificationWatcher = NotificationWatcher()
    private let batteryMonitor = BatteryMonitor()
    private let screenshotWatcher = ScreenshotWatcher()
    private var interaction: NotchInteractionMonitor!

    /// Low-battery warning: fire once when crossing below this while discharging.
    private static let lowBatteryThreshold = 20
    private var lastBatteryPercentage = 100

    private var targetScreen: NSScreen? { Settings.shared.resolvedScreen() }
    private var showUnread: Bool { Settings.shared.showUnreadCount && state.unreadCount > 0 }
    /// The collapsed pill widens when there's something to show in it.
    private var isCompact: Bool {
        (Settings.shared.showMusic && nowPlaying.track != nil)
            || state.notification != nil
            || showUnread
            || state.batteryFlash != nil
            || Settings.shared.batteryMode == .always
    }

    func install() {
        guard let screen = targetScreen else { return }
        geometry.notchWidth = NotchGeometry.detectNotchWidth(for: screen)
        geometry.topInset = NotchGeometry.detectTopInset(for: screen)
        geometry.offset = Settings.shared.notchOffset
        buildPanel(on: screen)
        nowPlaying.start()
        clipboard.start()
        startInteractionMonitor()
        startDragMonitor()
        startNotificationWatcher()
        startBatteryMonitor()
        startScreenshotWatcher()
        startEventMonitor()
        startGmail()
        startSystemMonitor()
        weather.start()
        windowsManager.start()
        observeStateChanges()
    }

    // MARK: - State observers

    private func observeStateChanges() {
        // Resize the interactive/drop region as the notch changes mode (collapsed
        // notch = small drop zone; expanded / preview / banner = full).
        Publishers.Merge3(
            state.$isExpanded.map { _ in () },
            state.$screenshot.map { _ in () },
            state.$notification.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.updateInteractiveRect() }
        .store(in: &cancellables)

        Settings.shared.$interactionMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateInteractiveRect() }
            .store(in: &cancellables)

        // Toggle drag-to-move (only takes effect while the island is interactive).
        // Also re-syncs the saved offset so the "Sıfırla" button (which zeroes the
        // offset then re-sets this flag) snaps the island back to center.
        Settings.shared.$movableNotch
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.geometry.offset = Settings.shared.notchOffset
                if let screen = self.targetScreen { self.positionPanel(on: screen) }
            }
            .store(in: &cancellables)

        // Move to the newly chosen screen when the user changes the setting.
        Settings.shared.$selectedDisplayID
            .receive(on: RunLoop.main)
            .dropFirst()
            .sink { [weak self] _ in self?.relocate() }
            .store(in: &cancellables)

        // Reposition if the screen configuration changes (display added/removed).
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.relocate() }
    }

    // MARK: - Interaction monitor

    private func startInteractionMonitor() {
        let context = NotchInteractionMonitor.Context(
            collapsedZone: { [weak self] in
                guard let self, let s = self.targetScreen else { return nil }
                return self.geometry.collapsedRect(on: s, isCompact: self.isCompact)
            },
            expandedZone: { [weak self] in
                guard let self, let s = self.targetScreen else { return nil }
                let hasMusic = Settings.shared.showMusic && self.nowPlaying.track != nil
                return self.geometry.expandedRect(on: s, hasMusic: hasMusic)
            },
            isExpanded: { [weak self] in self?.state.isExpanded ?? false },
            screenshotActive: { [weak self] in self?.state.screenshot != nil },
            hasTrack: { [weak self] in self?.nowPlaying.track != nil }
        )
        let monitor = NotchInteractionMonitor(context: context)
        monitor.onSetExpanded = { [weak self] in self?.state.isExpanded = $0 }
        monitor.onHoverChange = { [weak self] in self?.state.hovering = $0 }
        monitor.onNext = { [weak self] in self?.nowPlaying.next() }
        monitor.onPrevious = { [weak self] in self?.nowPlaying.previous() }
        monitor.start()
        interaction = monitor
    }

    // MARK: - App notifications (all apps)

    private func startNotificationWatcher() {
        notificationWatcher.onNewNotification = { [weak self] sender, message, appID in
            self?.flashNotification(sender: sender, message: message, appID: appID)
        }
        notificationWatcher.$unreadCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in self?.state.unreadCount = count }
            .store(in: &cancellables)
        notificationWatcher.start()
    }

    /// Briefly show the incoming message as a banner (with the sending app's
    /// icon), then clear it.
    private func flashNotification(sender: String, message: String, appID: String) {
        guard Settings.shared.showNotifications else { return }
        notificationClearItem?.cancel()
        let icon = appIcon(for: appID)
        state.whatsAppIcon = icon  // also the icon shown in the compact pill
        state.notification = NotchNotification(icon: icon, sender: sender, message: message)

        let clear = DispatchWorkItem { [weak self] in self?.state.notification = nil }
        notificationClearItem = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: clear)
    }

    private var iconCache: [String: NSImage] = [:]
    private func appIcon(for appID: String) -> NSImage? {
        if let cached = iconCache[appID] { return cached }
        guard let icon = NotificationWatcher.icon(forBundleID: appID) else { return nil }
        iconCache[appID] = icon
        return icon
    }

    // MARK: - Screenshot preview

    private func startScreenshotWatcher() {
        screenshotWatcher.onNewScreenshot = { [weak self] url in self?.showScreenshot(url) }
        screenshotWatcher.start()
    }

    private func showScreenshot(_ url: URL) {
        screenshotClearItem?.cancel()
        let thumb = ScreenshotActions.thumbnail(url)
        state.screenshot = ScreenshotPreview(url: url, image: thumb)
        let clear = DispatchWorkItem { [weak self] in self?.state.screenshot = nil }
        screenshotClearItem = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: clear)
    }

    // MARK: - Battery / charging flash

    private func startBatteryMonitor() {
        batteryMonitor.onPlugChange = { [weak self] _ in self?.flashBattery() }
        // Mirror live battery state into the shared UI state for the "always" mode,
        // and warn once when crossing below the low threshold while on battery.
        batteryMonitor.$percentage
            .receive(on: RunLoop.main)
            .sink { [weak self] p in
                self?.state.batteryPercentage = p
                self?.checkLowBattery(p)
            }
            .store(in: &cancellables)
        batteryMonitor.$isPlugged
            .receive(on: RunLoop.main)
            .sink { [weak self] plugged in self?.state.batteryPlugged = plugged }
            .store(in: &cancellables)
        batteryMonitor.start()
    }

    /// Flash a low-battery warning once, when the level first drops to/below the
    /// threshold while discharging. The flash is rendered red at low levels by
    /// the view, so we reuse `flashBattery()` for the visual.
    private func checkLowBattery(_ p: Int) {
        defer { lastBatteryPercentage = p }
        guard Settings.shared.batteryMode != .off, !batteryMonitor.isPlugged else { return }
        if lastBatteryPercentage > Self.lowBatteryThreshold && p <= Self.lowBatteryThreshold {
            flashBattery()
        }
    }

    // MARK: - Device / event flashes

    private func startEventMonitor() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] note in
            let name = (note.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL)?.lastPathComponent ?? "Disk"
            self?.flashEvent(symbol: "externaldrive.fill", title: "Bağlandı", message: name)
        }
        nc.addObserver(forName: NSWorkspace.didUnmountNotification, object: nil, queue: .main) { [weak self] _ in
            self?.flashEvent(symbol: "externaldrive.badge.minus", title: "Çıkarıldı", message: "Disk")
        }
    }

    /// A short banner flash for a system event (reuses the notification banner).
    private func flashEvent(symbol: String, title: String, message: String) {
        notificationClearItem?.cancel()
        let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        state.notification = NotchNotification(icon: icon, sender: title, message: message)
        let clear = DispatchWorkItem { [weak self] in self?.state.notification = nil }
        notificationClearItem = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: clear)
    }

    // MARK: - Brightness / volume HUD

    private func startSystemMonitor() {
        systemMonitor.onChange = { [weak self] hud in self?.flashHUD(hud) }
        systemMonitor.start()
    }

    private func flashHUD(_ hud: HUDInfo) {
        hudClearItem?.cancel()
        state.hud = hud
        let clear = DispatchWorkItem { [weak self] in self?.state.hud = nil }
        hudClearItem = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3, execute: clear)
    }

    // MARK: - Gmail

    private func startGmail() {
        gmail.onNewMessage = { [weak self] msg in
            self?.flashEvent(symbol: "envelope.fill", title: msg.author, message: msg.title)
        }
        gmail.start()
        Settings.shared.$gmailEmail
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.gmail.reconfigure() }
            .store(in: &cancellables)
    }

    private func flashBattery() {
        guard Settings.shared.batteryMode != .off else { return }
        batteryClearItem?.cancel()
        state.batteryFlash = BatteryFlash(
            percentage: batteryMonitor.percentage,
            isCharging: batteryMonitor.isPlugged
        )
        let clear = DispatchWorkItem { [weak self] in self?.state.batteryFlash = nil }
        batteryClearItem = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: clear)
    }

    // MARK: - Panel setup

    private func buildPanel(on screen: NSScreen) {
        let rootView = AnyView(
            NotchView(
                nowPlaying: nowPlaying,
                shelf: shelf,
                pomodoro: pomodoro,
                clipboard: clipboard,
                gmail: gmail,
                weather: weather,
                windows: windowsManager,
                lyrics: lyrics,
                notchWidth: geometry.notchWidth,
                topInset: geometry.topInset,
                isExpanded: Binding(
                    get: { [weak state] in state?.isExpanded ?? false },
                    set: { [weak state] in state?.isExpanded = $0 }
                )
            )
            .environmentObject(state)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )

        hostingView = PassthroughHostingView(rootView: rootView)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar + 2
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        // Mouse events are routed via the view's hitTest (interactiveRect) rather
        // than ignoring them wholesale, so the notch can accept file drops while
        // the rest stays click-through.
        panel.ignoresMouseEvents = false
        panel.contentView = hostingView
        panel.hidesOnDeactivate = false

        self.panel = panel
        positionPanel(on: screen)
        updateInteractiveRect()
        panel.orderFrontRegardless()
    }

    /// Update which part of the (fixed-size) window is interactive / drop-accepting.
    /// Collapsed → just the central notch (a drop target; wings stay click-through).
    /// Expanded / preview / banner → the whole island.
    private func updateInteractiveRect() {
        let W = NotchMetrics.expandedWidth
        let H = NotchMetrics.windowHeight
        let full = state.isExpanded || state.screenshot != nil || state.notification != nil
        hostingView.interactiveRect = full ? CGRect(x: 0, y: 0, width: W, height: H) : .zero
        // Collapsed → the whole window ignores mouse events, so NOTHING under the
        // notch is blocked (guaranteed passthrough). Open mechanisms don't need the
        // window to receive events: hover uses the mouse-location poll, click/swipe
        // use non-consuming global monitors.
        panel?.ignoresMouseEvents = !full
    }

    /// The window is always the full (max) size, top-anchored and centered.
    private func positionPanel(on screen: NSScreen) {
        panel.setFrame(geometry.windowFrame(on: screen), display: true)
    }

    // MARK: - Drag to move
    //
    // `isMovableByWindowBackground` doesn't work here: the SwiftUI content fills
    // the whole window so there's no draggable "background", and the collapsed
    // panel ignores mouse events entirely. Instead we drive the move ourselves
    // from non-consuming global+local monitors (which see the events even while
    // the panel is click-through), grabbing only from the top "handle" strip so
    // the controls below stay usable.

    private var dragStartMouse: NSPoint?
    private var dragStartOffset: CGSize = .zero

    private func startDragMonitor() {
        let down: (NSEvent) -> Void = { [weak self] _ in self?.dragBegin() }
        let move: (NSEvent) -> Void = { [weak self] _ in self?.dragChange() }
        let up: (NSEvent) -> Void = { [weak self] _ in self?.dragEnd() }
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { down($0) }
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { down($0); return $0 }
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { move($0) }
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { move($0); return $0 }
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { up($0) }
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { up($0); return $0 }
    }

    /// The grab strip: the top of the island (notch/pill area), so dragging never
    /// conflicts with the sliders/buttons in the expanded card below.
    private func dragHandleRect(_ screen: NSScreen) -> NSRect {
        let f = screen.frame
        let w = state.isExpanded
            ? NotchMetrics.expandedWidth
            : NotchMetrics.collapsedWidth(notchWidth: geometry.notchWidth, hasMusic: isCompact)
        let h = state.isExpanded ? geometry.topInset + 14 : NotchMetrics.collapsedHeight
        return NSRect(x: f.midX - w / 2 + geometry.offset.width,
                      y: f.maxY - h + geometry.offset.height, width: w, height: h)
    }

    private func dragBegin() {
        guard Settings.shared.movableNotch, let screen = targetScreen else { return }
        guard dragHandleRect(screen).contains(NSEvent.mouseLocation) else { return }
        dragStartMouse = NSEvent.mouseLocation
        dragStartOffset = geometry.offset
    }

    private func dragChange() {
        guard let start = dragStartMouse, let screen = targetScreen else { return }
        let mouse = NSEvent.mouseLocation
        let f = screen.frame
        var off = CGSize(width: dragStartOffset.width + (mouse.x - start.x),
                         height: dragStartOffset.height + (mouse.y - start.y))
        // Keep the whole island on screen so it can never be dragged out of sight.
        let maxX = max(0, f.width / 2 - NotchMetrics.expandedWidth / 2 - 8)
        let maxDown = max(0, f.height - NotchMetrics.collapsedHeight - 8)
        off.width = min(max(off.width, -maxX), maxX)
        off.height = min(max(off.height, -maxDown), 0)  // 0 = top edge, can't go above
        geometry.offset = off
        positionPanel(on: screen)
    }

    private func dragEnd() {
        guard dragStartMouse != nil else { return }
        dragStartMouse = nil
        Settings.shared.notchOffset = geometry.offset
    }

    /// Recompute which screen to use and move the panel there.
    private func relocate() {
        guard let screen = targetScreen else { return }
        geometry.notchWidth = NotchGeometry.detectNotchWidth(for: screen)
        positionPanel(on: screen)
        panel.orderFrontRegardless()
    }
}
