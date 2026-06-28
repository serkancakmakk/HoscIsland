import Foundation
import Combine

/// A calendar event parsed from an iCalendar (.ics) feed.
struct CalEvent: Equatable {
    var title: String
    var start: Date
    var allDay: Bool
}

/// Fetches a user-supplied iCalendar URL (Google/iCloud/Outlook all expose a
/// private "secret address in iCal format") and surfaces the next upcoming
/// event for the idle card. Permission-free and works the same on Linux
/// (`services/calendar.rs`).
final class CalendarManager: ObservableObject {
    @Published private(set) var nextEvent: CalEvent?

    private var timer: Timer?

    func start() {
        refresh()
        // Calendars change slowly; a 15-minute poll is plenty.
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // React to the URL being set/changed in Settings.
        NotificationCenter.default.addObserver(
            forName: .calendarURLChanged, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        guard let raw = Settings.shared.calendarURL,
              let url = URL(string: raw), !raw.isEmpty else {
            if nextEvent != nil { nextEvent = nil }
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let text = String(data: data, encoding: .utf8) else { return }
            let next = CalendarManager.parseNext(text)
            DispatchQueue.main.async {
                guard let self else { return }
                if self.nextEvent != next { self.nextEvent = next }
            }
        }.resume()
    }

    /// Parse the ICS text and return the soonest event starting from now.
    static func parseNext(_ ics: String, now: Date = Date()) -> CalEvent? {
        let lines = unfold(ics)
        var events: [CalEvent] = []
        var inEvent = false
        var summary = ""
        var start: Date?
        var allDay = false

        for line in lines {
            if line == "BEGIN:VEVENT" {
                inEvent = true; summary = ""; start = nil; allDay = false
            } else if line == "END:VEVENT" {
                if let start, !summary.isEmpty {
                    events.append(CalEvent(title: summary, start: start, allDay: allDay))
                }
                inEvent = false
            } else if inEvent {
                if line.hasPrefix("SUMMARY") {
                    summary = value(of: line)
                } else if line.hasPrefix("DTSTART") {
                    let (date, isDate) = parseDate(line)
                    start = date
                    allDay = isDate
                }
            }
        }

        // All-day events count if they're today or later; timed events if in the future.
        let cal = Calendar.current
        return events
            .filter { ev in
                ev.allDay ? cal.startOfDay(for: ev.start) >= cal.startOfDay(for: now)
                          : ev.start >= now
            }
            .min { $0.start < $1.start }
    }

    // MARK: - Parsing helpers

    /// RFC 5545 line unfolding: a line beginning with a space/tab continues the
    /// previous one.
    private static func unfold(_ ics: String) -> [String] {
        var out: [String] = []
        for raw in ics.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if (raw.hasPrefix(" ") || raw.hasPrefix("\t")), !out.isEmpty {
                out[out.count - 1] += raw.dropFirst()
            } else {
                out.append(raw)
            }
        }
        return out
    }

    /// The value after the first unescaped colon, with common ICS escapes undone.
    private static func value(of line: String) -> String {
        guard let idx = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: idx)...])
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Parse a `DTSTART…` line into a date and whether it's an all-day (DATE) value.
    private static func parseDate(_ line: String) -> (Date?, Bool) {
        let raw = value(of: line)
        let isDate = line.uppercased().contains("VALUE=DATE") || (raw.count == 8 && !raw.contains("T"))

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")

        if isDate {
            fmt.dateFormat = "yyyyMMdd"
            fmt.timeZone = TimeZone.current
            return (fmt.date(from: raw), true)
        }
        if raw.hasSuffix("Z") {
            fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            fmt.timeZone = TimeZone(identifier: "UTC")
            return (fmt.date(from: raw), false)
        }
        // Floating / TZID local time — approximate with the local zone.
        fmt.dateFormat = "yyyyMMdd'T'HHmmss"
        fmt.timeZone = TimeZone.current
        return (fmt.date(from: raw), false)
    }
}

extension Notification.Name {
    static let calendarURLChanged = Notification.Name("calendarURLChanged")
}
