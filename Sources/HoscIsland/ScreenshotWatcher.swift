import AppKit
import Foundation

/// Watches the macOS screenshot save location for newly captured images and
/// reports them so the notch can show a quick preview.
final class ScreenshotWatcher: ObservableObject {
    /// Called on the main thread with the URL of a newly captured screenshot.
    var onNewScreenshot: ((URL) -> Void)?

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var fallbackTimer: Timer?
    private var baseline = Date()
    private var seen = Set<String>()

    func start() {
        baseline = Date()
        watchDirectory()
        // Fallback in case a filesystem event is missed.
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func stop() {
        fallbackTimer?.invalidate(); fallbackTimer = nil
        source?.cancel(); source = nil
    }

    /// Watch the screenshot folder for changes — fires near-instantly when a new
    /// file is written, instead of waiting for the next poll.
    private func watchDirectory() {
        let dir = Self.screenshotDirectory()
        fileDescriptor = open(dir.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor, eventMask: [.write, .extend], queue: .main
        )
        src.setEventHandler { [weak self] in self?.check() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 { close(fd) }
            self?.fileDescriptor = -1
        }
        src.resume()
        source = src
    }

    private func check() {
        let dir = Self.screenshotDirectory()
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        ) else { return }

        var newest: (url: URL, date: Date)?
        for file in files {
            guard ["png", "jpg", "jpeg"].contains(file.pathExtension.lowercased()) else { continue }
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            guard created > baseline, !seen.contains(file.path) else { continue }
            if newest == nil || created > newest!.date { newest = (file, created) }
        }

        if let newest {
            seen.insert(newest.url.path)
            // `baseline` already excludes anything older, so `seen` only guards
            // against re-firing the current capture. Prune it once it grows so a
            // long-running session can't accumulate paths without bound.
            if seen.count > 64 { seen = [newest.url.path] }
            baseline = newest.date
            // The file may still be flushing to disk; a brief beat avoids a
            // partial-image read.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.onNewScreenshot?(newest.url)
            }
        }
    }

    /// The folder where macOS saves screenshots (defaults to the Desktop).
    static func screenshotDirectory() -> URL {
        if let loc = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let expanded = (loc as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Desktop", isDirectory: true)
    }
}

/// Quick actions for a captured screenshot.
enum ScreenshotActions {
    static func copy(_ url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func delete(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// A downscaled thumbnail for display in the notch.
    static func thumbnail(_ url: URL, maxWidth: CGFloat = 240) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        let size = image.size
        guard size.width > 0 else { return image }
        let scale = min(1, maxWidth / size.width)
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1)
        thumb.unlockFocus()
        return thumb
    }
}
