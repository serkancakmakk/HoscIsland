import AppKit
import ApplicationServices
import Combine

/// One on-screen window of another app.
struct WinItem: Identifiable, Equatable {
    let id: Int          // CGWindowNumber
    let pid: pid_t
    let app: String
    let title: String
}

/// Lists other apps' on-screen windows (via `CGWindowListCopyWindowInfo`) so the
/// island can offer a quick switcher. Window titles need Screen Recording
/// permission; without it we fall back to the app name. Clicking activates the
/// owning app.
final class WindowsManager: ObservableObject {
    @Published private(set) var windows: [WinItem] = []

    private var timer: Timer?
    private let ignored: Set<String> = ["HoscIsland", "Window Server", "Dock",
                                        "Control Center", "Spotlight", "Notification Center"]

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        let selfPid = ProcessInfo.processInfo.processIdentifier
        var result: [WinItem] = []
        for info in infos {
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else { continue }                       // normal windows only
            let pid = info[kCGWindowOwnerPID as String] as? pid_t ?? 0
            guard pid != selfPid else { continue }
            let app = info[kCGWindowOwnerName as String] as? String ?? ""
            guard !app.isEmpty, !ignored.contains(app) else { continue }
            let title = info[kCGWindowName as String] as? String ?? ""
            let number = info[kCGWindowNumber as String] as? Int ?? 0
            result.append(WinItem(id: number, pid: pid, app: app, title: title))
        }
        let trimmed = Array(result.prefix(12))
        if trimmed != windows { windows = trimmed }
    }

    func activate(_ item: WinItem) {
        NSRunningApplication(processIdentifier: item.pid)?
            .activate(options: [.activateIgnoringOtherApps])
    }

    func icon(_ item: WinItem) -> NSImage? {
        NSRunningApplication(processIdentifier: item.pid)?.icon
    }

    /// Whether the Accessibility permission needed to close windows is granted.
    var canControlWindows: Bool { AXIsProcessTrusted() }

    /// Close a window by pressing its accessibility close button. Needs the
    /// Accessibility permission; prompts for it the first time if missing.
    func close(_ item: WinItem) {
        guard AXIsProcessTrusted() else {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            return
        }
        let appEl = AXUIElementCreateApplication(item.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return }

        // Prefer the window whose title matches; fall back to the first.
        let target = windows.first { window in
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            return (titleRef as? String) == item.title
        } ?? windows.first
        guard let target else { return }

        var buttonRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target, kAXCloseButtonAttribute as CFString, &buttonRef) == .success,
              let button = buttonRef else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }
}
