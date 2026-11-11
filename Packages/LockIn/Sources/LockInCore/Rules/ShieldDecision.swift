import Foundation

/// The single rule that decides whether the Shield is up. Every target asks this, nothing else.
public enum ShieldDecision {
    public static func shouldShield(at now: Date, tasks: [LockInTask], completions: CompletionLog, calendar: Calendar) -> Bool {
        !owedTasks(at: now, tasks: tasks, completions: completions, calendar: calendar).isEmpty
    }

    /// Incomplete Required Tasks due today whose Start Time has passed: what the user owes right now.
    public static func owedTasks(at now: Date, tasks: [LockInTask], completions: CompletionLog, calendar: Calendar) -> [LockInTask] {
        let day = DayKey(now, calendar: calendar)
        return Today(day: day, tasks: tasks, completions: completions, calendar: calendar)
            .incompleteRequired
            .map(\.task)
            .filter { now >= $0.enforcementStart(on: day, calendar: calendar) }
    }
}
