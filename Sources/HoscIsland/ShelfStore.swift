import AppKit
import Combine

/// Holds the files dropped onto the notch "shelf". Persists the list of paths so
/// the shelf survives relaunches (missing files are pruned on load).
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [URL] = []

    private let defaults = UserDefaults.standard
    private let key = "shelfPaths"

    init() {
        let paths = defaults.stringArray(forKey: key) ?? []
        items = paths.map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        save()
    }

    func add(_ urls: [URL]) {
        var changed = false
        for url in urls where !items.contains(url) {
            items.append(url)
            changed = true
        }
        if changed { save() }
    }

    func remove(_ url: URL) {
        items.removeAll { $0 == url }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func save() {
        defaults.set(items.map { $0.path }, forKey: key)
    }

    static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}
