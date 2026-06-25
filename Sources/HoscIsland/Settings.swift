import AppKit
import Combine

/// How the battery indicator behaves.
enum BatteryMode: String, CaseIterable {
    case off        // never show
    case onChange   // flash only when plugged/unplugged
    case always     // always visible in the notch

    var label: String {
        switch self {
        case .off: return "Kapalı"
        case .onChange: return "Değişince"
        case .always: return "Her zaman"
        }
    }
}

/// User-facing settings, persisted in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()

    private let defaults = UserDefaults.standard
    private let displayKey = "selectedDisplayID"
    private let unreadKey = "showUnreadCount"
    private let notifKey = "showNotifications"
    private let musicKey = "showMusic"
    private let batteryKey = "batteryMode"

    /// Whether to show the WhatsApp unread-message count badge in the notch.
    @Published var showUnreadCount: Bool {
        didSet { defaults.set(showUnreadCount, forKey: unreadKey) }
    }

    /// Whether to show the WhatsApp incoming-message banner.
    @Published var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: notifKey) }
    }

    /// Whether to show the now-playing music indicator / controls.
    @Published var showMusic: Bool {
        didSet { defaults.set(showMusic, forKey: musicKey) }
    }

    /// Battery indicator behaviour.
    @Published var batteryMode: BatteryMode {
        didSet { defaults.set(batteryMode.rawValue, forKey: batteryKey) }
    }

    /// The CGDirectDisplayID the island should appear on.
    /// `nil` means "automatic" (prefer the screen with the notch).
    @Published var selectedDisplayID: CGDirectDisplayID? {
        didSet {
            if let id = selectedDisplayID {
                defaults.set(Int(id), forKey: displayKey)
            } else {
                defaults.removeObject(forKey: displayKey)
            }
        }
    }

    private init() {
        if defaults.object(forKey: displayKey) != nil {
            selectedDisplayID = CGDirectDisplayID(defaults.integer(forKey: displayKey))
        } else {
            selectedDisplayID = nil
        }
        showUnreadCount = (defaults.object(forKey: unreadKey) as? Bool) ?? true
        showNotifications = (defaults.object(forKey: notifKey) as? Bool) ?? true
        showMusic = (defaults.object(forKey: musicKey) as? Bool) ?? true
        batteryMode = BatteryMode(rawValue: defaults.string(forKey: batteryKey) ?? "") ?? .onChange
    }

    /// All currently connected screens, paired with their display IDs.
    static func availableScreens() -> [(id: CGDirectDisplayID, screen: NSScreen)] {
        NSScreen.screens.compactMap { screen in
            guard let id = displayID(of: screen) else { return nil }
            return (id, screen)
        }
    }

    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    /// Resolve the screen the island should currently use.
    func resolvedScreen() -> NSScreen? {
        let screens = Self.availableScreens()
        if let id = selectedDisplayID, let match = screens.first(where: { $0.id == id }) {
            return match.screen
        }
        // Automatic: prefer a screen with a notch, then the built-in/primary one.
        if let notched = screens.first(where: { $0.screen.safeAreaInsets.top > 0 }) {
            return notched.screen
        }
        return NSScreen.screens.first
    }

    static func isNotched(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0
    }
}
