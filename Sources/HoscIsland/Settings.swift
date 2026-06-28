import AppKit
import Combine

/// How the island opens.
enum InteractionMode: String, CaseIterable {
    case hover   // expands when the cursor is over the notch
    case click   // expands only when clicked (hover just nudges)

    var label: String {
        switch self {
        case .hover: return "Hover"
        case .click: return L("Tıkla", "Click")
        }
    }
}

/// Hover open/close timing — how eagerly the island reacts to the cursor.
enum HoverSensitivity: String, CaseIterable {
    case fast      // opens instantly, closes quickly
    case normal
    case relaxed   // small open delay, lingers before closing

    var label: String {
        switch self {
        case .fast: return L("Anında", "Instant")
        case .normal: return "Normal"
        case .relaxed: return L("Rahat", "Relaxed")
        }
    }
    /// Delay before opening on hover.
    var openDelay: TimeInterval {
        switch self {
        case .fast: return 0
        case .normal: return 0.12
        case .relaxed: return 0.30
        }
    }
    /// Delay before collapsing after the cursor leaves.
    var closeDelay: TimeInterval {
        switch self {
        case .fast: return 0.12
        case .normal: return 0.18
        case .relaxed: return 0.45
        }
    }
}

/// Corner rounding of the expanded island card.
enum CornerStyle: String, CaseIterable {
    case soft     // very round
    case medium   // default
    case sharp    // tight corners

    var label: String {
        switch self {
        case .soft: return L("Yumuşak", "Soft")
        case .medium: return L("Orta", "Medium")
        case .sharp: return L("Keskin", "Sharp")
        }
    }
    /// Bottom-corner radius of the expanded card.
    var expandedRadius: CGFloat {
        switch self {
        case .soft: return 22
        case .medium: return 14
        case .sharp: return 6
        }
    }
}

/// How the battery indicator behaves.
enum BatteryMode: String, CaseIterable {
    case off        // never show
    case onChange   // flash only when plugged/unplugged
    case always     // always visible in the notch

    var label: String {
        switch self {
        case .off: return L("Kapalı", "Off")
        case .onChange: return L("Değişince", "On change")
        case .always: return L("Her zaman", "Always")
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
    private let interactionKey = "interactionMode"
    private let hoverKey = "hoverSensitivity"
    private let cornerKey = "cornerStyle"
    private let languageKey = "language"
    private let movableKey = "movableNotch"
    private let offsetXKey = "notchOffsetX"
    private let offsetYKey = "notchOffsetY"
    private let gmailKey = "gmailEmail"
    private let calendarKey = "calendarURL"

    /// Whether the island opens on hover or on click.
    @Published var interactionMode: InteractionMode {
        didSet { defaults.set(interactionMode.rawValue, forKey: interactionKey) }
    }

    /// Hover open/close timing.
    @Published var hoverSensitivity: HoverSensitivity {
        didSet { defaults.set(hoverSensitivity.rawValue, forKey: hoverKey) }
    }

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

    /// Corner rounding style of the expanded card.
    @Published var cornerStyle: CornerStyle {
        didSet { defaults.set(cornerStyle.rawValue, forKey: cornerKey) }
    }

    /// UI language (TR/EN/system).
    @Published var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: languageKey) }
    }

    /// Whether the island can be dragged to a custom position.
    @Published var movableNotch: Bool {
        didSet { defaults.set(movableNotch, forKey: movableKey) }
    }

    /// Launch HoscIsland at login. Backed by the system login-item registration
    /// (`SMAppService`), not UserDefaults — `didSet` syncs it. (Skipped during
    /// init, where Swift doesn't fire `didSet`, so it reads the live status.)
    @Published var launchAtLogin: Bool {
        didSet { LoginItem.set(launchAtLogin) }
    }

    /// Custom position offset from the default top-center anchor (screen points,
    /// +x = right, +y = up). Persisted but not `@Published` — geometry reads it
    /// live while dragging.
    var notchOffset: CGSize {
        get { CGSize(width: defaults.double(forKey: offsetXKey), height: defaults.double(forKey: offsetYKey)) }
        set {
            defaults.set(Double(newValue.width), forKey: offsetXKey)
            defaults.set(Double(newValue.height), forKey: offsetYKey)
        }
    }

    /// Connected Gmail address (the app password lives in the Keychain). `nil`
    /// when not connected.
    @Published private(set) var gmailEmail: String? {
        didSet {
            if let e = gmailEmail { defaults.set(e, forKey: gmailKey) }
            else { defaults.removeObject(forKey: gmailKey) }
        }
    }

    var gmailConnected: Bool { gmailEmail != nil }

    /// iCalendar (.ics) feed URL for the "next event" widget. `nil` when unset.
    @Published var calendarURL: String? {
        didSet {
            if let u = calendarURL, !u.isEmpty { defaults.set(u, forKey: calendarKey) }
            else { defaults.removeObject(forKey: calendarKey) }
            NotificationCenter.default.post(name: .calendarURLChanged, object: nil)
        }
    }

    func connectGmail(email: String, appPassword: String) {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        Keychain.set(appPassword, account: trimmed)
        gmailEmail = trimmed
    }

    func disconnectGmail() {
        if let e = gmailEmail { Keychain.delete(account: e) }
        gmailEmail = nil
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
        interactionMode = InteractionMode(rawValue: defaults.string(forKey: interactionKey) ?? "") ?? .hover
        hoverSensitivity = HoverSensitivity(rawValue: defaults.string(forKey: hoverKey) ?? "") ?? .normal
        cornerStyle = CornerStyle(rawValue: defaults.string(forKey: cornerKey) ?? "") ?? .medium
        language = AppLanguage(rawValue: defaults.string(forKey: languageKey) ?? "") ?? .system
        movableNotch = (defaults.object(forKey: movableKey) as? Bool) ?? false
        gmailEmail = defaults.string(forKey: gmailKey)
        calendarURL = defaults.string(forKey: calendarKey)
        launchAtLogin = LoginItem.isEnabled
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
