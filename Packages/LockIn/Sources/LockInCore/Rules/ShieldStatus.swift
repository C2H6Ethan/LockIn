import Foundation

/// The blocking status line on Today (see GLOSSARY: Blocking status): whether blocking is on, and why.
/// Built on `ShieldDecision`, so whenever Screen Time is allowed and the Blocklist isn't empty, `isShieldUp`
/// is exactly what the extension enforces.
public struct ShieldStatus: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Screen Time access is missing, so nothing can be blocked. Overrides everything else.
        case needsScreenTime
        /// The Blocklist is empty, so there is nothing to block.
        case needsBlocklist
        /// Required Tasks are owed now. `left` counts every incomplete Required Task due today.
        case on(left: Int)
        /// Required Tasks remain, but none is enforced yet; blocking starts at the earliest Start Time.
        case startsAt(TimeOfDay, left: Int)
        /// A Bypass is active; blocking resumes at its end.
        case bypassed(until: Date, left: Int)
        /// Every Required Task due today is done: a Kept Day.
        case off
        /// No Required Task is due today.
        case noRequiredTasks
    }

    public let state: State
    /// When Lock Mode ends, while it's active.
    public let lockedUntil: Date?

    public var isShieldUp: Bool {
        if case .on = state { return true }
        return false
    }

    public static func current(now: Date, tasks: [LockInTask], completions: CompletionLog, bypasses: BypassLog,
                               lockMode: LockMode, screenTimeAllowed: Bool, blocklistIsEmpty: Bool,
                               calendar: Calendar) -> ShieldStatus {
        let lockedUntil = lockMode.isActive(at: now) ? lockMode.lockedUntil : nil
        return ShieldStatus(state: state(now: now, tasks: tasks, completions: completions, bypasses: bypasses,
                                         screenTimeAllowed: screenTimeAllowed, blocklistIsEmpty: blocklistIsEmpty,
                                         calendar: calendar),
                            lockedUntil: lockedUntil)
    }

    private static func state(now: Date, tasks: [LockInTask], completions: CompletionLog, bypasses: BypassLog,
                              screenTimeAllowed: Bool, blocklistIsEmpty: Bool, calendar: Calendar) -> State {
        guard screenTimeAllowed else { return .needsScreenTime }
        guard !blocklistIsEmpty else { return .needsBlocklist }

        let day = DayKey(now, calendar: calendar)
        let today = Today(day: day, tasks: tasks, completions: completions, calendar: calendar)
        guard !today.required.isEmpty else { return .noRequiredTasks }
        let left = today.incompleteRequired.map(\.task)
        guard !left.isEmpty else { return .off }

        let owed = ShieldDecision.owedTasks(at: now, tasks: tasks, completions: completions, calendar: calendar)
        if owed.isEmpty {
            // Nothing enforced yet, so every incomplete Task has a Start Time still ahead.
            let earliest = left.compactMap(\.startTime).min() ?? TimeOfDay(minutesSinceMidnight: 0)!
            return .startsAt(earliest, left: left.count)
        }
        if let bypass = bypasses.active(at: now) { return .bypassed(until: bypass.end, left: left.count) }
        return .on(left: left.count)
    }

    /// The words on screen. Never says "Shield" (see GLOSSARY: Shield).
    public struct Text: Equatable, Sendable {
        /// "Blocking on"
        public let lead: String
        /// "2 required tasks left"
        public let detail: String?
        /// The line asks the user to do something (accent color, tappable).
        public let isAction: Bool

        public init(_ state: State, calendar: Calendar) {
            switch state {
            case .on(let left):
                (lead, detail, isAction) = ("Blocking on", left == 1 ? "1 required task left" : "\(left) required tasks left", false)
            case .startsAt(let time, _):
                (lead, detail, isAction) = ("Blocking from \(time)", nil, false)
            case .bypassed(let until, _):
                let parts = calendar.dateComponents([.hour, .minute], from: until)
                // A Bypass ends on any minute, so this can't go through `TimeOfDay` (quarter hours only).
                let time = String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
                (lead, detail, isAction) = ("Blocking resumes at \(time)", "Bypass", false)
            case .off:
                (lead, detail, isAction) = ("Blocking off", "Day kept", false)
            case .noRequiredTasks:
                (lead, detail, isAction) = ("No required tasks today", nil, false)
            case .needsScreenTime:
                (lead, detail, isAction) = ("Blocking can't start", "allow Screen Time access", true)
            case .needsBlocklist:
                (lead, detail, isAction) = ("Nothing to block", "choose your Blocklist", true)
            }
        }
    }

    public func text(calendar: Calendar) -> Text { Text(state, calendar: calendar) }
}
