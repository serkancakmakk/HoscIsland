import Foundation
import Combine

/// A simple 25-minute Pomodoro countdown shown in the idle expanded card.
final class PomodoroTimer: ObservableObject {
    static let workDuration = 25 * 60

    @Published private(set) var remaining = PomodoroTimer.workDuration
    @Published private(set) var running = false

    private var timer: Timer?

    var label: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    func toggle() { running ? pause() : start() }

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
        remaining = Self.workDuration
    }

    private func tick() {
        guard remaining > 0 else { pause(); return }
        remaining -= 1
        if remaining == 0 { pause() }
    }
}
