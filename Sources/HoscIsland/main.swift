import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = NotchController()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.install()
        setupStatusItem()
    }

    /// A menu-bar item so the app can be configured / quit (it has no Dock icon).
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "circle.lefthalf.filled",
                                     accessibilityDescription: "HoscIsland")
        let menu = NSMenu()
        menu.addItem(withTitle: "HoscIsland", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: L("Ayarlar…", "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        let fda = menu.addItem(withTitle: L("Bildirimler için Tam Disk Erişimi…", "Full Disk Access for notifications…"),
                               action: #selector(openFullDiskAccess), keyEquivalent: "")
        fda.target = self
        menu.addItem(.separator())
        let quitItem = menu.addItem(withTitle: L("Çıkış", "Quit"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "HoscIsland Ayarları"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openFullDiskAccess() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)  // no Dock icon
app.run()
