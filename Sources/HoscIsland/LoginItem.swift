import Foundation
import ServiceManagement

/// Launch-at-login control via `SMAppService` (macOS 13+). Registers the running
/// `.app` as a login item; the registration persists across launches, so the
/// toggle just reflects/sets the system status.
enum LoginItem {
    static var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItem: \(enabled ? "register" : "unregister") başarısız: \(error)")
        }
    }
}
