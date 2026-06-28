import Foundation
import Combine

/// A simple Pomodoro countdown shown in the idle expanded card. The duration is
/// adjustable by tapping the timer (cycles through preset lengths).
final class PomodoroTimer: ObservableObject {
    /// Selectable work lengths in minutes (tapping the timer cycles these).
    static let presets = [15, 25, 45, 60]

    @Published private(set) var workMinutes = 25
    @Published private(set) var remaining = 25 * 60
    @Published private(set) var running = false

    private var timer: Timer?

    private var workDuration: Int { workMinutes * 60 }

    var label: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    func toggle() { running ? pause() : start() }

    /// Tap-to-change: jump to the next preset length and reset to it.
    func cycleDuration() {
        let idx = Self.presets.firstIndex(of: workMinutes) ?? 1
        workMinutes = Self.presets[(idx + 1) % Self.presets.count]
        pause()
        remaining = workDuration
    }

    func start() {
        guard !running, remaining > 0 else { return }
        running = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        running = false
        timer?.invalidate()
        timer = nil
    }

    func reset() {
        pause()
        remaining = workDuration
    }

    private func tick() {
        guard remaining > 0 else { pause(); return }
        remaining -= 1
        if remaining == 0 { pause() }
    }
}
