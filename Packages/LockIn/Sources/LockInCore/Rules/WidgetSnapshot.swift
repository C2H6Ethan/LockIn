import Foundation

/// What the home-screen widget shows. Read-only: built from the store, never writes.
public struct WidgetSnapshot: Hashable, Sendable {
    public let date: Date
    public let requiredDone: Int
    public let requiredTotal: Int
    public let undoneRequiredTitles: [String]
    public let streak: Int
    public let isKept: Bool

    public init(date: Date, requiredDone: Int, requiredTotal: Int, undoneRequiredTitles: [String], streak: Int, isKept: Bool) {
        self.date = date
        self.requiredDone = requiredDone
        self.requiredTotal = requiredTotal
        self.undoneRequiredTitles = undoneRequiredTitles
        self.streak = streak
        self.isKept = isKept
    }

    public static func make(tasks: [LockInTask], completions: CompletionLog, records: [DayKey: DayRecord],
                            settings: Settings, now: Date, calendar: Calendar) -> WidgetSnapshot {
        let today = Today(day: DayKey(now, calendar: calendar), tasks: tasks, completions: completions, calendar: calendar)
        return WidgetSnapshot(
            date: now,
            requiredDone: today.required.filter(\.isCompleted).count,
            requiredTotal: today.required.count,
            undoneRequiredTitles: today.incompleteRequired.map(\.task.title),
            streak: Streak.current(records: records, today: today, firstDay: settings.firstDay, seed: settings.streakSeed, calendar: calendar),
            isKept: today.isKept
        )
    }

    /// When the widget's content can change without the app: each later Start Time today, then midnight.
    public static func refreshDates(tasks: [LockInTask], now: Date, calendar: Calendar) -> [Date] {
        let day = DayKey(now, calendar: calendar)
        let starts = Set(tasks.filter(\.isRequired).compactMap(\.startTime)).map { day.instant(at: $0, in: calendar) }.filter { $0 > now }
        return starts.sorted() + [day.adding(days: 1, in: calendar).startOfDay(in: calendar)]
    }
}

extension WidgetSnapshot {
    /// Reads the snapshot from a store (the App Group in production).
    public static func read(from store: LockInStore, now: Date = Date(), calendar: Calendar = .current) -> WidgetSnapshot {
        make(tasks: store.read(.tasks), completions: store.read(.completions), records: store.read(.dayRecords),
             settings: store.read(.settings), now: now, calendar: calendar)
    }
}
