import Foundation
import LockInCore
import LockInPlatform
import Observation

/// The walk screen: count live steps until the Day's Bypass cost is reached, then start the Bypass.
@MainActor
@Observable
final class BypassModel {
    enum State: Equatable {
        case nothingOwed
        case walking(steps: Int, goal: Int)
        case active(until: Date)
        case motionDenied
        /// This device has no step counter (e.g. some iPads).
        case unavailable
    }

    private(set) var state: State = .nothingOwed

    private let store: LockInStore
    private let counter: StepCounter
    private let calendar: Calendar
    private let now: () -> Date
    private let startBypass: () -> Bypass

    init(store: LockInStore, counter: StepCounter, calendar: Calendar = .current, now: @escaping () -> Date = Date.init, startBypass: @escaping () -> Bypass) {
        self.store = store
        self.counter = counter
        self.calendar = calendar
        self.now = now
        self.startBypass = startBypass
    }

    func appear() {
        let now = now()
        let log = store.read(.bypasses)
        if let active = log.active(at: now) {
            state = .active(until: active.end)
            return
        }
        let shielded = ShieldDecision.shouldShield(at: now, tasks: store.read(.tasks), completions: store.read(.completions), bypasses: log, calendar: calendar)
        guard shielded else {
            state = .nothingOwed
            return
        }
        guard counter.isAvailable else {
            state = .unavailable
            return
        }
        state = .walking(steps: 0, goal: log.nextStepCost(on: DayKey(now, calendar: calendar), calendar: calendar))
        counter.start { [weak self] steps in
            Task { @MainActor in self?.receive(steps: steps) }
        }
    }

    func disappear() {
        counter.stop()
    }

    func receive(steps: Int?) {
        guard case .walking(_, let goal) = state else { return }
        guard let steps else {
            counter.stop()
            state = .motionDenied
            return
        }
        if steps >= goal {
            counter.stop()
            state = .active(until: startBypass().end)
        } else {
            state = .walking(steps: steps, goal: goal)
        }
    }

    var status: String {
        guard case .walking(let steps, let goal) = state, goal > 0 else { return "" }
        switch Double(steps) / Double(goal) {
        case ..<0.25: return "Get moving."
        case ..<0.75: return "Keep going."
        default: return "Almost there."
        }
    }
}
