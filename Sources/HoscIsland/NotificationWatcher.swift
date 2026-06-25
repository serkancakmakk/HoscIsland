import AppKit
import Combine
import Foundation
import SQLite3

/// Watches macOS's Notification Center database for new notifications from a
/// given app (WhatsApp by default) and fires a callback when one arrives.
///
/// Reading this database requires **Full Disk Access** — the user must grant it
/// in System Settings → Privacy & Security → Full Disk Access. Until then,
/// `hasAccess` stays false.
final class NotificationWatcher: ObservableObject {
    /// Bundle-id substring to match (case-insensitive), e.g. "whatsapp".
    private let bundleMatch: String
    /// Bundle id used to load the app icon to display.
    let appBundleID: String

    @Published private(set) var hasAccess = false
    /// Number of the app's notifications currently sitting in Notification Center
    /// (drops back down as the user reads them) — used as an unread approximation.
    @Published private(set) var unreadCount = 0

    /// Called on the main thread when a new matching notification appears,
    /// with the decoded sender (title) and message (body).
    var onNewNotification: ((_ sender: String, _ message: String) -> Void)?

    private var timer: Timer?
    private var lastRecID: Double = -1
    private var lastDelivered: Double = -1
    private var initialized = false

    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(bundleMatch: String = "whatsapp", appBundleID: String = "net.whatsapp.WhatsApp") {
        self.bundleMatch = bundleMatch
        self.appBundleID = appBundleID
    }

    private var dbPath: String {
        NSHomeDirectory() + "/Library/Group Containers/group.com.apple.usernoted/db2/db"
    }


    func start() {
        check()  // establishes the baseline & access state
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    /// Opens the DB fresh each poll so we always see the latest committed rows
    /// (a long-lived read-only connection can hold a stale snapshot).
    private func check() {
        var db: OpaquePointer?
        let uri = "file:\(dbPath)?mode=ro"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            setAccess(false)
            if db != nil { sqlite3_close(db) }
            return
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 300)
        setAccess(true)

        let join = "FROM record r JOIN app a ON r.app_id = a.app_id WHERE a.identifier LIKE ?"
        let maxID = queryDouble(db, "SELECT MAX(r.rec_id) \(join);") ?? -1
        let maxDelivered = queryDouble(db, "SELECT MAX(r.delivered_date) \(join);") ?? -1
        let count = queryDouble(db, "SELECT COUNT(*) \(join);") ?? 0
        setUnread(Int(count))

        if !initialized {
            // Don't fire for notifications that existed before we launched.
            initialized = true
            lastRecID = maxID
            lastDelivered = maxDelivered
            return
        }

        // Fire if a brand-new record appeared (rec_id up) OR an existing one was
        // re-delivered/updated (delivered_date up) — WhatsApp often coalesces
        // messages into one record, which only bumps delivered_date.
        let newRecord = maxID > lastRecID
        let reDelivered = maxDelivered > lastDelivered + 0.001
        if newRecord || reDelivered {
            lastRecID = max(lastRecID, maxID)
            lastDelivered = max(lastDelivered, maxDelivered)
            let msg = latestMessage(db) ?? ("WhatsApp", "")
            DispatchQueue.main.async { [weak self] in self?.onNewNotification?(msg.0, msg.1) }
        }
    }

    /// Decode the sender (title) and message (body) of the newest matching
    /// notification from its archived `data` blob (a binary property list).
    private func latestMessage(_ db: OpaquePointer?) -> (String, String)? {
        let sql = """
        SELECT r.data FROM record r JOIN app a ON r.app_id = a.app_id
        WHERE a.identifier LIKE ? ORDER BY r.delivered_date DESC, r.rec_id DESC LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, "%\(bundleMatch)%", -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let blob = sqlite3_column_blob(stmt, 0) else { return nil }
        let length = Int(sqlite3_column_bytes(stmt, 0))
        let data = Data(bytes: blob, count: length)

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else { return nil }
        // The notification request lives under "req"; titl/subt/body hold the text.
        let req = (dict["req"] as? [String: Any]) ?? dict
        let title = (req["titl"] as? String) ?? "WhatsApp"
        let subtitle = req["subt"] as? String
        let body = (req["body"] as? String) ?? ""
        let sender = [title, subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return (sender.isEmpty ? "WhatsApp" : sender, body)
    }

    private func queryDouble(_ db: OpaquePointer?, _ sql: String) -> Double? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, "%\(bundleMatch)%", -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        if sqlite3_column_type(stmt, 0) == SQLITE_NULL { return nil }
        return sqlite3_column_double(stmt, 0)
    }

    private func setUnread(_ value: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.unreadCount != value else { return }
            self.unreadCount = value
        }
    }

    private func setAccess(_ value: Bool) {
        if Thread.isMainThread {
            if hasAccess != value { hasAccess = value }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.hasAccess != value else { return }
                self.hasAccess = value
            }
        }
    }

    // MARK: - App icon

    func loadAppIcon() -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appBundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
