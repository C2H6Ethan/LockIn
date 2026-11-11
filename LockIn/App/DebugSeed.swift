#if DEBUG
import Foundation
import LockInCore
import LockInPlatform

/// Launch with `-seed` to fill the store with sample data for screenshots and manual checks.
/// Add `-seedFrom` (only a later Start Time left), `-seedDone` (Day kept), `-seedBypass` (Bypass active),
/// `-seedLocked` (Lock Mode for 7 days), `-seedOnboarding` (onboarding again), `-seedEmpty` (nothing due today) or `-seedNoScreenTime` (see `DebugLaunch`).
enum DebugSeed {
    static func applyIfRequested(to store: LockInStore, calendar: Calendar = .current) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-seed") else { return }
        let today = DayKey(Date(), calendar: calendar)
        let every = Schedule.weekly(Set(Weekday.allCases))
        let read = LockInTask(title: "Read 20 pages", schedule: every, requirement: .required, createdOn: today)
        let workout = LockInTask(title: "Morning workout", schedule: every, requirement: .required, createdOn: today)
        let walk = LockInTask(title: "Walk", schedule: every, requirement: .required, createdOn: today, kind: .stepGoal(target: 8000))
        let gym = LockInTask(title: "Go to the gym", schedule: every, requirement: .required, startTime: TimeOfDay(hour: 23, minute: 30), createdOn: today)
        var tasks = [
            read, workout, walk, gym,
            LockInTask(title: "Stretch", schedule: every, requirement: .optional, createdOn: today),
            LockInTask(title: "Journal", schedule: every, requirement: .optional, createdOn: today),
            LockInTask(title: "Climbing", schedule: .weekly([.monday, .wednesday]), requirement: .required, createdOn: today,
                       kind: .location(Place(name: "Minimum Boulder", latitude: 47.38, longitude: 8.53))),
        ]
        var log = CompletionLog()
        log.set(read.id, completed: true, on: today)
        if args.contains("-seedFrom") || args.contains("-seedDone") {
            [workout, walk].forEach { log.set($0.id, completed: true, on: today) }
        }
        if args.contains("-seedDone") { log.set(gym.id, completed: true, on: today) }
        if args.contains("-seedEmpty") {
            // Nothing due today, but Tasks on other days.
            let notToday = Set(Weekday.allCases).subtracting([today.weekday(in: calendar)])
            tasks = [
                LockInTask(title: "Long run", schedule: .weekly(notToday), requirement: .required, createdOn: today),
                LockInTask(title: "Dentist", schedule: .once(today.adding(days: 2, in: calendar)), requirement: .required, createdOn: today),
            ]
        }
        store.write(tasks, to: .tasks)
        store.write(log, to: .completions)
        store.write(StepsToday(day: today, total: 5210), to: .stepsToday)
        // The simulator can't pick apps, so seed a website-only Blocklist.
        store.write(Blocklist(customDomains: ["reddit.com", "x.com", "youtube.com"]), to: .blocklist)
        var bypasses = BypassLog()
        if args.contains("-seedBypass") { bypasses.start(at: Date().addingTimeInterval(-6 * 60), calendar: calendar) }
        store.write(bypasses, to: .bypasses)
        var lockMode = LockMode()
        if args.contains("-seedLocked") { lockMode.lock(days: 7, now: Date()) }
        store.write(lockMode, to: .lockMode)
        var settings = store.read(.settings)
        settings.hasCompletedOnboarding = true
        settings.firstDay = today
        settings.streakSeed = StreakSeed(count: 11, asOf: today.adding(days: -1, in: calendar))
        store.write(settings, to: .settings)
        store.write([:], to: .dayRecords)
        if args.contains("-seedOnboarding") {
            settings.hasCompletedOnboarding = false
            store.write(settings, to: .settings)
        }
        if args.contains("-seedMissed") { seedMissedDays(store: store, today: today, calendar: calendar) }
        if args.contains("-seedMissedYesterday") { seedMissedDays(store: store, today: today, calendar: calendar, missedCount: 1) }
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
