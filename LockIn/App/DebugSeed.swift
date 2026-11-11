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
    }
}
#endif
