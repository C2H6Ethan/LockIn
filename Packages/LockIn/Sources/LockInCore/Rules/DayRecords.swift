import Foundation

/// How a Day ended. Written once, when the Day is over, and never changed by later edits.
public struct DayRecord: Hashable, Codable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case kept, missed
        /// A Missed Day the user spent a Streak Freeze on. Counts as Kept.
        case frozen
    }

    public let day: DayKey
    /// The Required Tasks due that Day, as they were named at the end of it.
    public let requiredDue: [TaskSnapshot]
    public let completedRequired: Set<LockInTask.ID>
    public var outcome: Outcome

    public init(day: DayKey, requiredDue: [TaskSnapshot], completedRequired: Set<LockInTask.ID>, outcome: Outcome) {
        self.day = day
        self.requiredDue = requiredDue
        self.completedRequired = completedRequired
        self.outcome = outcome
    }

    public var undoneRequired: [TaskSnapshot] {
        requiredDue.filter { !completedRequired.contains($0.id) }
    }

    public var countsAsKept: Bool { outcome != .missed }
}

public struct TaskSnapshot: Hashable, Codable, Sendable {
    public let id: LockInTask.ID
    public let title: String

    public init(id: LockInTask.ID, title: String) {
        self.id = id
        self.title = title
    }
}

public enum DayRecords {
    /// Adds a record for every Day from `firstDay` through `through` that doesn't have one yet.
    /// Idempotent; the first writer wins. Days nobody finalized in time are built from the current Tasks (best effort).
    public static func finalized(
        existing: [DayKey: DayRecord],
        through lastDay: DayKey,
        firstDay: DayKey?,
        tasks: [LockInTask],
        completions: CompletionLog,
        calendar: Calendar
    ) -> [DayKey: DayRecord] {
        guard let firstDay, firstDay <= lastDay else { return existing }
        var records = existing
        // Start after the newest existing record so long histories aren't rescanned every time.
        var day = records.keys.filter { $0 >= firstDay }.max().map { $0.adding(days: 1, in: calendar) } ?? firstDay
        while day <= lastDay {
            if records[day] == nil {
                let today = Today(day: day, tasks: tasks, completions: completions, calendar: calendar)
                records[day] = DayRecord(
                    day: day,
                    requiredDue: today.required.map { TaskSnapshot(id: $0.task.id, title: $0.task.title) },
                    completedRequired: Set(today.required.filter(\.isCompleted).map(\.task.id)),
                    outcome: today.isKept ? .kept : .missed
                )
            }
            day = day.adding(days: 1, in: calendar)
        }
        return records
    }
}

extension Document where Value == [DayKey: DayRecord] {
    public static let dayRecords = Document("dayRecords") { [:] }
}
