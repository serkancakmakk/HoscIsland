import AppKit
import Combine

/// Keeps a short history of copied text. Polls the general pasteboard's
/// `changeCount` (the only reliable change signal on macOS) and prepends new
/// entries; tapping one copies it back.
final class ClipboardManager: ObservableObject {
    @Published private(set) var items: [String] = []

    private var changeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let maxItems = 6

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != changeCount else { return }
        changeCount = pb.changeCount
        guard let text = pb.string(forType: .string) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        if items.count > maxItems { items.removeLast(items.count - maxItems) }
    }

    /// Copy an entry back to the pasteboard (without re-capturing our own write).
    func copy(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        changeCount = pb.changeCount
    }

    func clear() { items.removeAll() }
}
