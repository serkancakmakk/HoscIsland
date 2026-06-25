import Foundation
import IOKit.ps

/// Reads battery state via IOKit and notifies when the power source changes
/// (e.g. the charger is plugged in / unplugged) so the notch can flash a
/// charging indicator.
final class BatteryMonitor: ObservableObject {
    @Published private(set) var percentage: Int = 100
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var isPlugged: Bool = false

    /// Called on the main thread when AC power is connected/disconnected.
    var onPlugChange: ((_ plugged: Bool) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var lastPlugged: Bool?

    func start() {
        update()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { monitor.update() }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        runLoopSource = nil
    }

    private func update() {
        guard let snapshot = Self.read() else { return }
        percentage = snapshot.percentage
        isCharging = snapshot.isCharging
        isPlugged = snapshot.isPlugged

        if lastPlugged != snapshot.isPlugged {
            let wasKnown = lastPlugged != nil
            lastPlugged = snapshot.isPlugged
            if wasKnown { onPlugChange?(snapshot.isPlugged) }
        }
    }

    private static func read() -> (percentage: Int, isCharging: Bool, isPlugged: Bool)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let percentage = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let plugged = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (percentage, isCharging, plugged)
        }
        return nil
    }
}
