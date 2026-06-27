import CoreAudio
import CoreGraphics
import Foundation

/// Polls display brightness and system output volume; reports a `HUDInfo` when
/// either changes, so the island can show its own HUD instead of the system OSD.
final class SystemMonitor {
    var onChange: ((HUDInfo) -> Void)?

    private var timer: Timer?
    private var lastBrightness: Float = -1
    private var lastVolume: Float = -1

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        if let b = Self.brightness() {
            if lastBrightness >= 0, abs(b - lastBrightness) > 0.005 {
                onChange?(HUDInfo(kind: .brightness, level: Double(b)))
            }
            lastBrightness = b
        }
        if let v = Self.volume() {
            if lastVolume >= 0, abs(v - lastVolume) > 0.005 {
                onChange?(HUDInfo(kind: .volume, level: Double(v)))
            }
            lastVolume = v
        }
    }

    // MARK: - Brightness (private DisplayServices, loaded via dlopen)

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private static let getBrightness: GetBrightness? = {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_LAZY),
              let sym = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(sym, to: GetBrightness.self)
    }()

    static func brightness() -> Float? {
        guard let fn = getBrightness else { return nil }
        var value: Float = 0
        return fn(CGMainDisplayID(), &value) == 0 ? value : nil
    }

    // MARK: - Volume (CoreAudio default output device)

    static func volume() -> Float? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var deviceAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &deviceAddr, 0, nil, &size, &device
        ) == noErr else { return nil }

        var volume = Float32(0)
        var vsize = UInt32(MemoryLayout<Float32>.size)
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(device, &volAddr, 0, nil, &vsize, &volume) == noErr else {
            return nil
        }
        return volume
    }
}
