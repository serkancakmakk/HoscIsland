import AppKit
import Combine

/// Surfaces the most recently modified files in `~/Downloads` so the expanded
/// card can offer quick access. Polls the folder (cheap, permission-free) and
/// publishes the newest few. Linux counterpart: `services/downloads.rs`.
final class DownloadsManager: ObservableObject {
    @Published private(set) var items: [URL] = []

    private var timer: Timer?
    private let maxItems = 8

    private var dir: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let dir = self.dir
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let found = Self.read(dir, limit: self.maxItems)
            DispatchQueue.main.async {
                if self.items != found { self.items = found }
            }
        }
    }

    /// Newest-first regular files, skipping hidden and still-downloading items.
    private static func read(_ dir: URL, limit: Int) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey, .isHiddenKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries
            .filter { url in
                let v = try? url.resourceValues(forKeys: Set(keys))
                guard v?.isRegularFile == true, v?.isHidden != true else { return false }
                // Skip browsers' in-progress files.
                return !["download", "crdownload", "part"].contains(url.pathExtension.lowercased())
            }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return da > db
            }
            .prefix(limit)
            .map { $0 }
    }
}
