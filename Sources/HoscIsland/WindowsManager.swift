import AppKit
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
}
