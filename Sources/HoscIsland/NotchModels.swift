import AppKit
import SwiftUI

// MARK: - Transient content models

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

/// A transient brightness/volume HUD (replaces the system's center OSD).
struct HUDInfo: Equatable {
    enum Kind { case brightness, volume }
    let id = UUID()
    var kind: Kind
    var level: Double  // 0...1
    static func == (l: HUDInfo, r: HUDInfo) -> Bool { l.id == r.id }
}

/// A past notification kept in the expanded card's history list.
struct NotchHistoryItem: Identifiable, Equatable {
    let id = UUID()
    var icon: NSImage?
    var sender: String
    var message: String
    var date: Date
    static func == (l: NotchHistoryItem, r: NotchHistoryItem) -> Bool { l.id == r.id }
}

/// A screenshot preview with quick actions.
struct ScreenshotPreview: Equatable {
    let id = UUID()
    var url: URL
    var image: NSImage?
    static func == (l: ScreenshotPreview, r: ScreenshotPreview) -> Bool { l.id == r.id }
}

// MARK: - Shared UI state

/// UI state shared between the controller and the SwiftUI view.
final class NotchState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var notification: NotchNotification?
    /// When true, the current banner shows even if the notification-banner
    /// setting is off (e.g. a Pomodoro-finished alert the user asked for).
    @Published var notificationForced = false
    @Published var unreadCount: Int = 0
    @Published var batteryFlash: BatteryFlash?
    @Published var batteryPercentage: Int = 100
    @Published var batteryPlugged: Bool = false
    @Published var screenshot: ScreenshotPreview?
    @Published var hud: HUDInfo?
    /// Recent notifications, newest first, for the expanded card's history list.
    @Published var notificationHistory: [NotchHistoryItem] = []
    /// Cursor is over the collapsed notch (used for the click-mode hover nudge).
    @Published var hovering: Bool = false
    var whatsAppIcon: NSImage?
}

// MARK: - Key-capable panel

/// The notch panel is borderless + non-activating, so it normally can't become
/// the key window (no text input). We flip `keyEligible` on only while an inline
/// field (e.g. the Pomodoro length) is being edited, so a normal notch click
/// never steals keyboard focus from the user's frontmost app.
final class KeyablePanel: NSPanel {
    var keyEligible = false
    override var canBecomeKey: Bool { keyEligible }
}

/// Exposes the hosting `NSWindow` to SwiftUI (so we can toggle key eligibility
/// for inline editing).
struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { onResolve(v.window) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Passthrough hosting view

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
