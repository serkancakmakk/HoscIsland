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
    @Published var unreadCount: Int = 0
    @Published var batteryFlash: BatteryFlash?
    @Published var batteryPercentage: Int = 100
    @Published var batteryPlugged: Bool = false
    @Published var screenshot: ScreenshotPreview?
    /// Cursor is over the collapsed notch (used for the click-mode hover nudge).
    @Published var hovering: Bool = false
    var whatsAppIcon: NSImage?
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
