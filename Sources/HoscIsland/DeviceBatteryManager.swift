import Foundation

/// A connected accessory's battery reading (AirPods / Magic Mouse / keyboard …).
struct DeviceBattery: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var percentage: Int
    /// SF Symbol approximating the device kind.
    var symbol: String
}

/// Polls `ioreg` for Bluetooth/HID accessories that report a `BatteryPercent`,
/// so the expanded card can list their charge. Linux counterpart lives in
/// `services/devices_battery.rs` (UPower).
final class DeviceBatteryManager: ObservableObject {
    @Published private(set) var devices: [DeviceBattery] = []

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let found = Self.read()
            DispatchQueue.main.async {
                guard let self else { return }
                if self.devices != found { self.devices = found }
            }
        }
    }

    /// Run `ioreg`, then pull `"Product"` + `"BatteryPercent"` out of each node.
    private static func read() -> [DeviceBattery] {
        guard let output = runIOReg() else { return [] }
        var result: [DeviceBattery] = []
        // Nodes are separated by lines introducing a new service ("+-o <name>").
        for chunk in output.components(separatedBy: "+-o ") {
            guard let percent = match(#"\"BatteryPercent\" = (\d+)"#, in: chunk),
                  let pct = Int(percent), pct > 0 else { continue }
            let name = matchString(#"\"Product\" = \"([^\"]+)\""#, in: chunk)
                ?? matchString(#"\"BatteryName\" = \"([^\"]+)\""#, in: chunk)
                ?? "Aygıt"
            result.append(DeviceBattery(name: name, percentage: pct, symbol: symbol(for: name)))
        }
        // Dedupe by name (a device can surface under more than one service).
        var seen = Set<String>()
        return result.filter { seen.insert($0.name).inserted }
    }

    private static func runIOReg() -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"
        task.arguments = ["-r", "-l", "-k", "BatteryPercent"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do { try task.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    private static func match(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func matchString(_ pattern: String, in text: String) -> String? {
        match(pattern, in: text)
    }

    private static func symbol(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("airpod") || n.contains("headphone") || n.contains("buds") { return "airpods" }
        if n.contains("mouse") { return "magicmouse" }
        if n.contains("keyboard") { return "keyboard" }
        if n.contains("trackpad") { return "trackpad" }
        return "dot.radiowaves.left.and.right"
    }
}
