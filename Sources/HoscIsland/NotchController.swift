import AppKit
import SwiftUI
import Combine

/// A transient notification banner to flash in the notch.
struct NotchNotification: Equatable {
    let id = UUID()
    var icon: NSImage?
    var sender: String
    var message: String
    static func == (l: NotchNotification, r: NotchNotification) -> Bool { l.id == r.id }
}

/// A transient battery/charging flash.
struct BatteryFlash: Equatable {
    let id = UUID()
    var percentage: Int
    var isCharging: Bool
    static func == (l: BatteryFlash, r: BatteryFlash) -> Bool { l.id == r.id }
}

/// A screenshot preview with quick actions.
struct ScreenshotPreview: Equatable {
    let id = UUID()
    var url: URL
    var image: NSImage?
    static func == (l: ScreenshotPreview, r: ScreenshotPreview) -> Bool { l.id == r.id }
}

/// Shared UI state shared between the controller and the SwiftUI view.
final class NotchState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var notification: NotchNotification?
    @Published var unreadCount: Int = 0
    @Published var batteryFlash: BatteryFlash?
    @Published var batteryPercentage: Int = 100
    @Published var batteryPlugged: Bool = false
    @Published var screenshot: ScreenshotPreview?
    var whatsAppIcon: NSImage?
}

/// Hosting view that is only "solid" (hit-testable, drop-accepting) within
/// `interactiveRect`; clicks elsewhere pass through to the menu bar underneath.
/// Used so the collapsed notch can accept file drops while the wide compact pill
/// wings stay click-through.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var interactiveRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: nil)
        return interactiveRect.contains(local) ? super.hitTest(point) : nil
    }
}

final class NotchController {
    private var panel: NSPanel!
    private var hostingView: PassthroughHostingView<AnyView>!
    private let state = NotchState()
    private let nowPlaying = NowPlayingManager()
    private let shelf = ShelfStore()
    private var notchWidth: CGFloat = 200
    private var topInset: CGFloat = 38
    private var cancellables = Set<AnyCancellable>()
    private var collapseWorkItem: DispatchWorkItem?
    private var notificationClearItem: DispatchWorkItem?
    private var hoverTimer: Timer?

    private let notificationWatcher = NotificationWatcher()
    private let batteryMonitor = BatteryMonitor()
    private let screenshotWatcher = ScreenshotWatcher()
    private var cachedWhatsAppIcon: NSImage?
    private var batteryClearItem: DispatchWorkItem?
    private var screenshotClearItem: DispatchWorkItem?

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
        notchWidth = Self.detectNotchWidth(for: screen)
        topInset = Self.detectTopInset(for: screen)
        buildPanel(on: screen)
        nowPlaying.start()
        startHoverMonitor()
        startNotificationWatcher()
        startBatteryMonitor()
        startScreenshotWatcher()

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

    // MARK: - WhatsApp notifications

    private func startNotificationWatcher() {
        cachedWhatsAppIcon = notificationWatcher.loadAppIcon()
        state.whatsAppIcon = cachedWhatsAppIcon
        notificationWatcher.onNewNotification = { [weak self] sender, message in
            self?.flashNotification(sender: sender, message: message)
        }
        notificationWatcher.$unreadCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in self?.state.unreadCount = count }
            .store(in: &cancellables)
        notificationWatcher.start()
    }

    /// Update which part of the (fixed-size) window is interactive / drop-accepting.
    /// Collapsed → just the central notch (a drop target; wings stay click-through).
    /// Expanded / preview / banner → the whole island.
    private func updateInteractiveRect() {
        let W = NotchMetrics.expandedWidth
        let H = NotchMetrics.windowHeight
        let full = state.isExpanded || state.screenshot != nil || state.notification != nil
        if full {
            hostingView.interactiveRect = CGRect(x: 0, y: 0, width: W, height: H)
        } else {
            // Central notch drop zone (slightly taller for easier targeting).
            let w = notchWidth
            let h = NotchMetrics.collapsedHeight + 14
            hostingView.interactiveRect = CGRect(x: (W - w) / 2, y: H - h, width: w, height: h)
        }
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
        // Mirror live battery state into the shared UI state for the "always" mode.
        batteryMonitor.$percentage
            .receive(on: RunLoop.main)
            .sink { [weak self] p in self?.state.batteryPercentage = p }
            .store(in: &cancellables)
        batteryMonitor.$isPlugged
            .receive(on: RunLoop.main)
            .sink { [weak self] plugged in self?.state.batteryPlugged = plugged }
            .store(in: &cancellables)
        batteryMonitor.start()
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

    /// Briefly show the incoming message as a banner, then clear it.
    private func flashNotification(sender: String, message: String) {
        guard Settings.shared.showNotifications else { return }
        notificationClearItem?.cancel()
        state.notification = NotchNotification(icon: cachedWhatsAppIcon, sender: sender, message: message)

        let clear = DispatchWorkItem { [weak self] in self?.state.notification = nil }
        notificationClearItem = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: clear)
    }

    /// Recompute which screen to use and move the panel there.
    private func relocate() {
        guard let screen = targetScreen else { return }
        notchWidth = Self.detectNotchWidth(for: screen)
        positionPanel(on: screen)
        panel.orderFrontRegardless()
    }

    // MARK: - Panel setup

    private func buildPanel(on screen: NSScreen) {
        let rootView = AnyView(
            NotchView(
                nowPlaying: nowPlaying,
                shelf: shelf,
                notchWidth: notchWidth,
                topInset: topInset,
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

    // MARK: - Hover via mouse-location polling
    //
    // We poll the cursor position instead of using tracking areas because a
    // tracking area requires the window to *capture* mouse events, which would
    // block clicks to the menu bar sitting under the collapsed pill. Polling lets
    // the collapsed window stay fully click-through (`ignoresMouseEvents = true`).

    private func startHoverMonitor() {
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            self?.checkHover()
        }
    }

    private func checkHover() {
        guard let screen = targetScreen else { return }
        // While a screenshot preview is up it owns the notch; don't hover-expand.
        if state.screenshot != nil { return }
        let mouse = NSEvent.mouseLocation
        let zone = state.isExpanded ? expandedScreenRect(screen) : collapsedScreenRect(screen)

        if zone.contains(mouse) {
            collapseWorkItem?.cancel()
            if !state.isExpanded { state.isExpanded = true }
        } else if state.isExpanded, collapseWorkItem == nil {
            // Small delay so flicking past an edge doesn't collapse instantly.
            let work = DispatchWorkItem { [weak self] in
                self?.state.isExpanded = false
                self?.collapseWorkItem = nil
            }
            collapseWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
        }
    }

    // MARK: - Geometry (screen coordinates, bottom-left origin)

    private func collapsedScreenRect(_ screen: NSScreen) -> NSRect {
        let f = screen.frame
        let w = NotchMetrics.collapsedWidth(notchWidth: notchWidth, hasMusic: isCompact)
        let h = NotchMetrics.collapsedHeight
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }

    private func expandedScreenRect(_ screen: NSScreen) -> NSRect {
        let f = screen.frame
        let w = NotchMetrics.expandedWidth
        let h = NotchMetrics.windowHeight
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }

    /// The window is always the full (max) size, top-anchored and centered.
    private func positionPanel(on screen: NSScreen) {
        let width = NotchMetrics.expandedWidth
        let height = NotchMetrics.windowHeight
        let f = screen.frame
        panel.setFrame(
            NSRect(x: f.midX - width / 2, y: f.maxY - height, width: width, height: height),
            display: true
        )
    }

    // MARK: - Notch detection

    static func detectNotchWidth(for screen: NSScreen) -> CGFloat {
        // On notched Macs the safe-area top inset is > 0 and the auxiliary
        // top-left/right areas describe the regions either side of the notch.
        if #available(macOS 12.0, *), screen.safeAreaInsets.top > 0 {
            let left = screen.auxiliaryTopLeftArea?.maxX ?? 0
            let right = screen.auxiliaryTopRightArea?.minX ?? screen.frame.width
            let width = right - left
            if width > 60 && width < 400 { return width }
        }
        // Fallback width for Macs without a physical notch.
        return 190
    }

    /// Vertical space taken by the camera/notch (the menu-bar height on notched
    /// Macs). Used to keep the expanded content clear of the camera.
    static func detectTopInset(for screen: NSScreen) -> CGFloat {
        let inset = screen.safeAreaInsets.top
        return inset > 0 ? inset : 12  // non-notched Macs need only a small margin
    }
}
