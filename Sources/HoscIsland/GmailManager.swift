import Foundation
import Combine

/// A single unread Gmail message from the Atom feed.
struct GmailMessage: Identifiable, Equatable {
    let id: String
    let title: String
    let author: String
    let link: String
}

/// Reads recent unread Gmail via the account's Atom feed
/// (`https://mail.google.com/mail/feed/atom`) using HTTP Basic auth with the
/// user's email + an **App Password** (Google Account → Security → App passwords).
///
/// This avoids the OAuth/Google-Cloud setup an API client would need. It only
/// reads unread headers (sender + subject), never message bodies.
final class GmailManager: ObservableObject {
    @Published private(set) var messages: [GmailMessage] = []
    @Published private(set) var unread: Int = 0
    @Published private(set) var connected = false

    /// Called when a genuinely new message arrives (not on the first fetch).
    var onNewMessage: ((GmailMessage) -> Void)?

    private var timer: Timer?
    private var seenIDs = Set<String>()
    private var firstFetch = true

    func start() {
        timer?.invalidate()
        connected = Settings.shared.gmailConnected
        guard connected else { return }
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    /// Re-read settings (after the user connects/disconnects) and restart.
    func reconfigure() {
        firstFetch = true
        seenIDs.removeAll()
        messages = []
        unread = 0
        start()
    }

    private func fetch() {
        guard let email = Settings.shared.gmailEmail,
              let password = Keychain.get(account: email),
              let url = URL(string: "https://mail.google.com/mail/feed/atom") else {
            connected = false
            return
        }
        var req = URLRequest(url: url)
        let credentials = Data("\(email):\(password)".utf8).base64EncodedString()
        req.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 20

        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            guard let self else { return }
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            guard ok, let data else {
                DispatchQueue.main.async { self.connected = ok }
                return
            }
            let parsed = GmailFeedParser.parse(data)
            DispatchQueue.main.async {
                self.connected = true
                self.unread = parsed.fullCount
                self.messages = parsed.messages
                for m in parsed.messages where !self.seenIDs.contains(m.id) {
                    self.seenIDs.insert(m.id)
                    if !self.firstFetch { self.onNewMessage?(m) }
                }
                self.firstFetch = false
            }
        }.resume()
    }
}

/// Tiny XMLParser delegate for the Gmail Atom feed.
private final class GmailFeedParser: NSObject, XMLParserDelegate {
    static func parse(_ data: Data) -> (fullCount: Int, messages: [GmailMessage]) {
        let p = GmailFeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        parser.parse()
        return (p.fullCount, p.messages)
    }

    private var messages: [GmailMessage] = []
    private var fullCount = 0
    private var buffer = ""
    private var inEntry = false
    private var title = "", author = "", idStr = "", link = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        buffer = ""
        if name == "entry" {
            inEntry = true
            title = ""; author = ""; idStr = ""; link = ""
        } else if name == "link", inEntry {
            link = attributes["href"] ?? link
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if name == "fullcount", !inEntry {
            fullCount = Int(text) ?? 0
        } else if inEntry {
            switch name {
            case "title": title = text
            case "name": author = text
            case "id": idStr = text
            case "entry":
                messages.append(GmailMessage(
                    id: idStr.isEmpty ? "\(author)|\(title)" : idStr,
                    title: title.isEmpty ? "(konu yok)" : title,
                    author: author.isEmpty ? "Gmail" : author,
                    link: link
                ))
                inEntry = false
            default: break
            }
        }
    }
}
