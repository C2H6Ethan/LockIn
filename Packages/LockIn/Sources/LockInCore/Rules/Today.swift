import Foundation

/// The Tasks due on one Day with their completion state (see GLOSSARY: Today).
public struct Today: Sendable {
    public struct Entry: Hashable, Sendable {
        public let task: LockInTask
        public let isCompleted: Bool
    }

    public let day: DayKey
    /// Required Tasks first, ordered by Start Time (none first), then title.
    public let required: [Entry]
    public let optional: [Entry]

    public init(day: DayKey, tasks: [LockInTask], completions: CompletionLog, calendar: Calendar) {
        self.day = day
        let due = tasks
            .filter { $0.isDue(on: day, calendar: calendar) }
            .sorted { lhs, rhs in
                let l = lhs.startTime?.minutesSinceMidnight ?? -1
                let r = rhs.startTime?.minutesSinceMidnight ?? -1
                return l != r ? l < r : lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
            .map { Entry(task: $0, isCompleted: completions.isCompleted($0.id, on: day)) }
        required = due.filter { $0.task.isRequired }
        optional = due.filter { !$0.task.isRequired }
    }

    public var all: [Entry] { required + optional }

    public var incompleteRequired: [Entry] { required.filter { !$0.isCompleted } }

    /// A Kept Day: every due Required Task is done, or none are due.
    public var isKept: Bool { incompleteRequired.isEmpty }
}
