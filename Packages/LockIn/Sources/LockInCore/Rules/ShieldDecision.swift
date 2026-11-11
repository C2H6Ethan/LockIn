import Foundation

/// The single rule that decides whether the Shield is up. Every target asks this, nothing else.
public enum ShieldDecision {
    public static func shouldShield(at now: Date, tasks: [LockInTask], completions: CompletionLog, calendar: Calendar) -> Bool {
        let day = DayKey(now, calendar: calendar)
        return Today(day: day, tasks: tasks, completions: completions, calendar: calendar)
            .incompleteRequired
            .contains { now >= $0.task.enforcementStart(on: day, calendar: calendar) }
    }
}
