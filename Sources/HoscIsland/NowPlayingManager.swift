import AppKit
import Combine
import Foundation

/// Polls the currently playing track from Music.app and Spotify.
///
/// We use AppleScript (via the `osascript` subprocess) instead of the private
/// MediaRemote framework because, since macOS 15.4, MediaRemote's now-playing
/// APIs are restricted to Apple-signed apps. Running `osascript` as a subprocess
/// — rather than NSAppleScript in-process — avoids the background-thread deadlock
/// NSAppleScript hits when it needs to show the first Automation consent prompt,
/// and lets us enforce a timeout.
final class NowPlayingManager: ObservableObject {
    struct Track: Equatable {
        var title: String
        var artist: String
        var album: String
        var isPlaying: Bool
        var source: Source
        var artworkSignature: String  // changes when artwork should be reloaded
        var duration: Double = 0      // seconds
        var position: Double = 0      // seconds (advanced locally between polls)
        var shuffle: Bool = false
        var repeatOn: Bool = false
    }

    enum Source: String {
        case music = "Music"
        case spotify = "Spotify"
        case none = "None"
    }

    @Published var track: Track?
    @Published var artwork: NSImage?
    @Published var volume: Double = 0.5  // system output volume, 0...1

    private var timer: Timer?
    private let artworkPath = NSTemporaryDirectory() + "pilotnotch_artwork"
    private var lastArtworkSignature: String = ""

    /// Serial queue so we never run two AppleScripts at once (which could stack
    /// multiple consent prompts) and never block the main thread.
    private let scriptQueue = DispatchQueue(label: "com.pilot.notch.applescript")
    private var isPolling = false

    private var positionTimer: Timer?

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        // Advance the playback position locally so the progress bar moves smoothly
        // between the (slower) AppleScript polls.
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, var t = self.track, t.isPlaying, t.duration > 0 else { return }
            t.position = min(t.position + 0.5, t.duration)
            self.track = t
        }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        positionTimer?.invalidate(); positionTimer = nil
    }

    // MARK: - Polling

    private func poll() {
        // Skip if a previous poll (e.g. blocked on the first consent prompt) is
        // still in flight.
        if isPolling { return }
        isPolling = true
        scriptQueue.async { [weak self] in
            guard let self else { return }
            let newTrack = self.fetchActiveTrack()
            let vol = self.fetchSystemVolume()
            DispatchQueue.main.async {
                self.isPolling = false
                self.track = newTrack
                if let vol { self.volume = vol }
                if let t = newTrack, t.artworkSignature != self.lastArtworkSignature {
                    self.lastArtworkSignature = t.artworkSignature
                    self.loadArtwork(for: t.source)
                } else if newTrack == nil {
                    self.artwork = nil
                    self.lastArtworkSignature = ""
                }
            }
        }
    }

    private func fetchSystemVolume() -> Double? {
        guard let raw = runAppleScript("output volume of (get volume settings)"),
              let v = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return min(max(v / 100.0, 0), 1)
    }

    /// Prefer whichever app is actually playing; fall back to whichever is running.
    private func fetchActiveTrack() -> Track? {
        var musicTrack: Track?
        var spotifyTrack: Track?

        if isRunning("Music") { musicTrack = fetchTrack(source: .music) }
        if isRunning("Spotify") { spotifyTrack = fetchTrack(source: .spotify) }

        if let m = musicTrack, m.isPlaying { return m }
        if let s = spotifyTrack, s.isPlaying { return s }
        return musicTrack ?? spotifyTrack
    }

    private func isRunning(_ appName: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.localizedName == appName || $0.bundleIdentifier == bundleID(appName)
        }
    }

    private func bundleID(_ appName: String) -> String {
        switch appName {
        case "Music": return "com.apple.Music"
        case "Spotify": return "com.spotify.client"
        default: return ""
        }
    }

    private func fetchTrack(source: Source) -> Track? {
        // Properties differ between Spotify and Music.
        let idProperty = source == .spotify ? "id" : "database ID"
        let shuffleProp = source == .spotify ? "shuffling" : "shuffle enabled"
        let repeatProp = source == .spotify ? "repeating" : "song repeat"
        // NB: avoid AppleScript reserved words for variable names (e.g. `st`).
        // Spotify reports duration in milliseconds, Music in seconds.
        let script = """
        tell application "\(source.rawValue)"
            try
                set pstate to (player state as string)
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackID to (\(idProperty) of current track) as string
                set trackDur to (duration of current track) as string
                set trackPos to (player position) as string
                set shuf to (\(shuffleProp) as string)
                set rep to (\(repeatProp) as string)
                return pstate & "|~|" & trackName & "|~|" & trackArtist & "|~|" & trackAlbum & "|~|" & trackID & "|~|" & trackDur & "|~|" & trackPos & "|~|" & shuf & "|~|" & rep
            on error
                return "stopped|~||~||~||~||~|0|~|0|~|false|~|off"
            end try
        end tell
        """
        guard let raw = runAppleScript(script), !raw.isEmpty else { return nil }
        return parse(raw, source: source)
    }

    private func parse(_ raw: String, source: Source) -> Track? {
        let parts = raw.components(separatedBy: "|~|")
        guard parts.count >= 5 else { return nil }
        let state = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = parts[1]
        guard !title.isEmpty else { return nil }

        func field(_ i: Int) -> String { parts.count > i ? parts[i] : "" }

        // Duration: Spotify gives milliseconds, Music gives seconds.
        let rawDur = Double(field(5).replacingOccurrences(of: ",", with: ".")) ?? 0
        let duration = source == .spotify ? rawDur / 1000.0 : rawDur
        let position = Double(field(6).replacingOccurrences(of: ",", with: ".")) ?? 0
        let shuffle = field(7).lowercased() == "true"
        // Spotify: "true"/"false"; Music: "off"/"one"/"all".
        let repeatRaw = field(8).lowercased()
        let repeatOn = repeatRaw == "true" || repeatRaw == "all" || repeatRaw == "one"

        return Track(
            title: title,
            artist: parts[2],
            album: parts[3],
            isPlaying: state == "playing",
            source: source,
            artworkSignature: source.rawValue + ":" + parts[4],
            duration: duration,
            position: position,
            shuffle: shuffle,
            repeatOn: repeatOn
        )
    }

    // MARK: - Artwork

    private func loadArtwork(for source: Source) {
        scriptQueue.async { [weak self] in
            guard let self else { return }
            let image: NSImage?
            switch source {
            case .music:   image = self.loadMusicArtwork()
            case .spotify: image = self.loadSpotifyArtwork()
            case .none:    image = nil
            }
            DispatchQueue.main.async { self.artwork = image }
        }
    }

    private func loadMusicArtwork() -> NSImage? {
        let path = artworkPath + ".tiff"
        let script = """
        tell application "Music"
            try
                set d to raw data of artwork 1 of current track
                set f to (open for access (POSIX file "\(path)") with write permission)
                set eof f to 0
                write d to f
                close access f
                return "ok"
            on error
                try
                    close access f
                end try
                return "no"
            end try
        end tell
        """
        guard let r = runAppleScript(script), r.contains("ok") else { return nil }
        return NSImage(contentsOfFile: path)
    }

    private func loadSpotifyArtwork() -> NSImage? {
        let script = """
        tell application "Spotify"
            try
                return artwork url of current track
            on error
                return ""
            end try
        end tell
        """
        guard let urlString = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: urlString),
              let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }

    // MARK: - Controls

    func playPause() { control("playpause") }
    func next() { control("next track") }
    func previous() { control("previous track") }

    /// Seek the current track to `seconds`.
    func seek(to seconds: Double) {
        guard let source = track?.source, source != .none else { return }
        let app = source.rawValue
        if var t = track { t.position = seconds; track = t }  // optimistic
        scriptQueue.async { [weak self] in
            _ = self?.runAppleScript("tell application \"\(app)\" to set player position to \(seconds)")
        }
    }

    func toggleShuffle() {
        guard let t = track, t.source != .none else { return }
        let newValue = !t.shuffle
        if var nt = track { nt.shuffle = newValue; track = nt }  // optimistic
        let prop = t.source == .spotify ? "shuffling" : "shuffle enabled"
        scriptQueue.async { [weak self] in
            _ = self?.runAppleScript("tell application \"\(t.source.rawValue)\" to set \(prop) to \(newValue)")
        }
    }

    func toggleRepeat() {
        guard let t = track, t.source != .none else { return }
        let newValue = !t.repeatOn
        if var nt = track { nt.repeatOn = newValue; track = nt }  // optimistic
        let command: String
        if t.source == .spotify {
            command = "set repeating to \(newValue)"
        } else {
            command = "set song repeat to \(newValue ? "all" : "off")"  // Music enum
        }
        scriptQueue.async { [weak self] in
            _ = self?.runAppleScript("tell application \"\(t.source.rawValue)\" to \(command)")
        }
    }

    /// Set the system output volume (0...1).
    func setVolume(_ value: Double) {
        let pct = Int((min(max(value, 0), 1) * 100).rounded())
        volume = min(max(value, 0), 1)  // optimistic
        scriptQueue.async { [weak self] in
            _ = self?.runAppleScript("set volume output volume \(pct)")
        }
    }

    /// Bring the playing app (Music/Spotify) to the front.
    func activateApp() {
        guard let source = track?.source, source != .none else { return }
        let app = source.rawValue
        scriptQueue.async { [weak self] in
            _ = self?.runAppleScript("tell application \"\(app)\" to activate")
        }
    }

    private func control(_ command: String) {
        guard let source = track?.source, source != .none else { return }
        let app = source.rawValue
        scriptQueue.async { [weak self] in
            _ = self?.runAppleScript("tell application \"\(app)\" to \(command)")
            DispatchQueue.main.async { [weak self] in self?.poll() }
        }
    }

    // MARK: - AppleScript runner (osascript subprocess)

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]  // read the script from stdin (handles multi-line cleanly)
        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return nil
        }

        inPipe.fileHandleForWriting.write(Data(source.utf8))
        inPipe.fileHandleForWriting.closeFile()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let err = String(data: errData, encoding: .utf8) ?? ""
            NSLog("PilotNotch osascript error: \(err.trimmingCharacters(in: .whitespacesAndNewlines))")
            return nil
        }
        return String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
