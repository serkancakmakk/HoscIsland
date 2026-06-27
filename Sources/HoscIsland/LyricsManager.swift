import Foundation
import Combine

/// Fetches time-synced lyrics from lrclib.net (no API key) and exposes the line
/// for the current playback position. One line is shown under the now-playing
/// info, updating as the song plays.
final class LyricsManager: ObservableObject {
    @Published private(set) var lines: [(time: Double, text: String)] = []

    private var currentKey = ""

    /// Call when the track changes; refetches only when the song actually changes.
    func update(title: String, artist: String, album: String, duration: Double) {
        let key = "\(title)|\(artist)"
        guard key != currentKey, !title.isEmpty else { return }
        currentKey = key
        lines = []
        fetch(title: title, artist: artist, album: album, duration: duration)
    }

    /// The lyric line active at `position` seconds, if any.
    func line(at position: Double) -> String? {
        guard !lines.isEmpty else { return nil }
        var result: String?
        for entry in lines {
            if entry.time <= position + 0.2 { result = entry.text } else { break }
        }
        return result?.isEmpty == true ? nil : result
    }

    private func fetch(title: String, artist: String, album: String, duration: Double) {
        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        comps.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(Int(duration))),
        ]
        guard let url = comps.url else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let data = try? Data(contentsOf: url),
                  let resp = try? JSONDecoder().decode(LrclibResponse.self, from: data),
                  let synced = resp.syncedLyrics, !synced.isEmpty else { return }
            let parsed = Self.parseLRC(synced)
            DispatchQueue.main.async {
                guard self?.currentKey == "\(title)|\(artist)" else { return }
                self?.lines = parsed
            }
        }
    }

    /// Parse `[mm:ss.xx] text` lines into a sorted (seconds, text) list.
    static func parseLRC(_ lrc: String) -> [(time: Double, text: String)] {
        var result: [(Double, String)] = []
        for raw in lrc.split(separator: "\n") {
            let line = String(raw)
            var idx = line.startIndex
            var times: [Double] = []
            while idx < line.endIndex, line[idx] == "[" {
                guard let close = line[idx...].firstIndex(of: "]") else { break }
                let tag = line[line.index(after: idx)..<close]
                if let t = parseTimeTag(String(tag)) { times.append(t) }
                idx = line.index(after: close)
            }
            let text = String(line[idx...]).trimmingCharacters(in: .whitespaces)
            for t in times { result.append((t, text)) }
        }
        return result.sorted { $0.0 < $1.0 }.map { (time: $0.0, text: $0.1) }
    }

    private static func parseTimeTag(_ tag: String) -> Double? {
        // mm:ss.xx
        let parts = tag.split(separator: ":")
        guard parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
        return m * 60 + s
    }

    private struct LrclibResponse: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }
}
