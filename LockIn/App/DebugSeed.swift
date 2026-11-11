#if DEBUG
import Foundation
import LockInCore

/// Launch with `-seed` to fill the store with sample data for screenshots and manual checks.
enum DebugSeed {
    static func applyIfRequested(to store: LockInStore, calendar: Calendar = .current) {
        guard ProcessInfo.processInfo.arguments.contains("-seed") else { return }
        let today = DayKey(Date(), calendar: calendar)
        let every = Schedule.weekly(Set(Weekday.allCases))
        let read = LockInTask(title: "Read 20 pages", schedule: every, requirement: .required, createdOn: today)
        let tasks = [
            read,
            LockInTask(title: "Morning workout", schedule: every, requirement: .required, createdOn: today),
            LockInTask(title: "Go to the gym", schedule: every, requirement: .required, startTime: TimeOfDay(hour: 23, minute: 30), createdOn: today),
            LockInTask(title: "Stretch", schedule: every, requirement: .optional, createdOn: today),
            LockInTask(title: "Journal", schedule: every, requirement: .optional, createdOn: today),
        ]
        store.write(tasks, to: .tasks)
        var log = CompletionLog()
        log.set(read.id, completed: true, on: today)
        store.write(log, to: .completions)
        var settings = store.read(.settings)
        settings.hasCompletedOnboarding = true
        settings.firstDay = today
        settings.streakSeed = StreakSeed(count: 11, asOf: today.adding(days: -1, in: calendar))
        store.write(settings, to: .settings)
        store.write([:], to: .dayRecords)
        if ProcessInfo.processInfo.arguments.contains("-seedMissed") { seedMissedDays(store: store, today: today, calendar: calendar) }
        if ProcessInfo.processInfo.arguments.contains("-seedMissedYesterday") { seedMissedDays(store: store, today: today, calendar: calendar, missedCount: 1) }
    }

    /// `-seed -seedMissed`: a 12-day Streak broken by three Missed Days, for the recap.
    /// `-seedMissedYesterday`: broken by only yesterday, so the recap offers a Streak Freeze.
    private static func seedMissedDays(store: LockInStore, today: DayKey, calendar: Calendar, missedCount: Int = 3) {
        let first = today.adding(days: -(12 + missedCount), in: calendar)
        var records: [DayKey: DayRecord] = [:]
        for offset in 0..<12 {
            let d = first.adding(days: offset, in: calendar)
            records[d] = DayRecord(day: d, requiredDue: [], completedRequired: [], outcome: .kept)
        }
        let missed: [[String]] = [["Read 20 pages", "Stretch", "Journal", "Meditate", "Call mom", "Drink water", "Walk"], ["Morning workout"], ["Read 20 pages", "Go for a walk"]]
        for (i, titles) in missed.suffix(missedCount).enumerated() {
            let d = first.adding(days: 12 + i, in: calendar)
            records[d] = DayRecord(day: d, requiredDue: titles.map { TaskSnapshot(id: UUID(), title: $0) }, completedRequired: [], outcome: .missed)
        }
        store.write(records, to: .dayRecords)
        var settings = store.read(.settings)
        settings.firstDay = first
        settings.streakSeed = nil
        settings.recapAcknowledgedThrough = nil
        settings.streakFreezeUsedOn = nil
        store.write(settings, to: .settings)
    }
}
#endif
