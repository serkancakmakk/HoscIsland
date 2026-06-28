import AppKit
import Combine
import Foundation
import SQLite3

/// Watches macOS's Notification Center database for new notifications and fires a
/// callback when one arrives. By default it matches **all apps**; pass a
/// `bundleMatch` substring to restrict to one app.
///
/// Reading this database requires **Full Disk Access** — the user must grant it
/// in System Settings → Privacy & Security → Full Disk Access. Until then,
/// `hasAccess` stays false.
final class NotificationWatcher: ObservableObject {
    /// Bundle-id substring to match (case-insensitive), or `nil` for all apps.
    private let bundleMatch: String?

    @Published private(set) var hasAccess = false
    /// Number of notifications currently sitting in Notification Center (drops as
    /// the user reads them) — used as an unread approximation.
    @Published private(set) var unreadCount = 0

    /// Called on the main thread when a new notification appears, with the decoded
    /// sender (title), message (body), and originating app bundle id (for its icon).
    var onNewNotification: ((_ sender: String, _ message: String, _ appID: String) -> Void)?

    private var timer: Timer?
    private var lastRecID: Double = -1
    private var lastDelivered: Double = -1
    private var initialized = false

    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(bundleMatch: String? = nil) {
        self.bundleMatch = bundleMatch
    }

    /// `WHERE a.identifier LIKE ?` only when restricting to one app.
    private var whereClause: String {
        bundleMatch != nil ? "WHERE a.identifier LIKE ?" : ""
    }

    private func bindMatch(_ stmt: OpaquePointer?) {
        if let bundleMatch {
            sqlite3_bind_text(stmt, 1, "%\(bundleMatch)%", -1, SQLITE_TRANSIENT)
        }
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
        // Open read-WRITE first: macOS's notification DB is in WAL mode, and a
        // read-only handle can't touch the -shm index, so it serves a *stale*
        // snapshot — the count then appears frozen and never drops as you read
        // notifications. A read-write handle (the file is user-owned; we only
        // SELECT) reads the live WAL. Fall back to read-only if that's denied.
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) != SQLITE_OK {
            if db != nil { sqlite3_close(db); db = nil }
            let uri = "file:\(dbPath)?mode=ro"
            guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
                setAccess(false)
                if db != nil { sqlite3_close(db) }
                return
            }
        }
        defer { sqlite3_close(db) }
        sqlite3_busy_timeout(db, 300)
        setAccess(true)

        let join = "FROM record r JOIN app a ON r.app_id = a.app_id \(whereClause)"
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
            let msg = latestMessage(db) ?? ("Bildirim", "", "")
            DispatchQueue.main.async { [weak self] in self?.onNewNotification?(msg.0, msg.1, msg.2) }
        }
    }

    /// Decode the sender (title), message (body), and app id of the newest
    /// matching notification from its archived `data` blob (a binary plist).
    private func latestMessage(_ db: OpaquePointer?) -> (String, String, String)? {
        let sql = """
        SELECT r.data, a.identifier FROM record r JOIN app a ON r.app_id = a.app_id
        \(whereClause) ORDER BY r.delivered_date DESC, r.rec_id DESC LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        bindMatch(stmt)
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let blob = sqlite3_column_blob(stmt, 0) else { return nil }
        let length = Int(sqlite3_column_bytes(stmt, 0))
        let data = Data(bytes: blob, count: length)
        let appID = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else { return nil }
        // The notification request lives under "req"; titl/subt/body hold the text.
        let req = (dict["req"] as? [String: Any]) ?? dict
        let title = (req["titl"] as? String) ?? "Bildirim"
        let subtitle = req["subt"] as? String
        let body = (req["body"] as? String) ?? ""
        let sender = [title, subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return (sender.isEmpty ? "Bildirim" : sender, body, appID)
    }

    private func queryDouble(_ db: OpaquePointer?, _ sql: String) -> Double? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        bindMatch(stmt)
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

    static func icon(forBundleID appID: String) -> NSImage? {
        guard !appID.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
