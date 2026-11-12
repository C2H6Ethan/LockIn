#if DEBUG
import Foundation
import LockInCore
import LockInPlatform

/// Launch with `-seed` to fill the store with sample data for screenshots and manual checks.
/// Add `-seedFrom` (only a later Start Time left), `-seedDone` (Day kept), `-seedBypass` (Bypass active),
/// `-seedLocked` (Lock Mode for 7 days), `-seedOnboarding` (onboarding again), `-seedEmpty` (nothing due today) or `-seedNoScreenTime` (see `DebugLaunch`).
/// Marketing Captures (ticket 028), each through the real data path:
/// `-seedSteps <n>` (today's step total), `-seedStepsRise <from> <to> <seconds>` (the total climbs after launch),
/// `-seedVisited` (Climbing is due daily and visited today), `-seedPedometer <n>` (the Bypass walk counts up from `n`)
/// and `-seedStreak <n>` (a Streak of `n` days).
enum DebugSeed {
    static func applyIfRequested(to store: LockInStore, calendar: Calendar = .current,
                                 arguments args: [String] = ProcessInfo.processInfo.arguments) {
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
            LockInTask(title: "Climbing", schedule: args.contains("-seedVisited") ? every : .weekly([.monday, .wednesday]), requirement: .required, createdOn: today,
                       kind: .location(Place(name: "Minimum Boulder", latitude: 47.38, longitude: 8.53))),
        ]
        var log = CompletionLog()
        log.set(read.id, completed: true, on: today)
        if args.contains("-seedFrom") || args.contains("-seedDone") {
            [workout, walk].forEach { log.set($0.id, completed: true, on: today) }
        }
        if args.contains("-seedDone") { log.set(gym.id, completed: true, on: today) }
        var visits = VisitLog()
        if args.contains("-seedVisited"), let climbing = tasks.first(where: { $0.place != nil }) {
            visits.record(climbing.id, on: today, calendar: calendar)
            if args.contains("-seedDone") { log.set(climbing.id, completed: true, on: today) }
        }
        if args.contains("-seedEmpty") {
            // Nothing due today, but Tasks on other days.
            let notToday = Set(Weekday.allCases).subtracting([today.weekday(in: calendar)])
            tasks = [
                LockInTask(title: "Long run", schedule: .weekly(notToday), requirement: .required, createdOn: today),
                LockInTask(title: "Dentist", schedule: .once(today.adding(days: 2, in: calendar)), requirement: .required, createdOn: today),
            ]
        }
        // Today's steps, and the Step-Goal Tasks they reach (the rule `Enforcement.recordSteps` applies).
        let steps = intValue(after: "-seedSteps", in: args) ?? StepsRise(arguments: args)?.from ?? 5210
        for id in StepGoal.completions(tasks: tasks, stepsToday: steps, day: today, calendar: calendar) {
            log.set(id, completed: true, on: today)
        }
        store.write(tasks, to: .tasks)
        store.write(log, to: .completions)
        store.write(visits, to: .visits)
        store.write(StepsToday(day: today, total: steps), to: .stepsToday)
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
        settings.streakSeed = StreakSeed(count: intValue(after: "-seedStreak", in: args) ?? 11, asOf: today.adding(days: -1, in: calendar))
        store.write(settings, to: .settings)
        store.write([:], to: .dayRecords)
        if args.contains("-seedOnboarding") {
            settings.hasCompletedOnboarding = false
            store.write(settings, to: .settings)
        }
        if args.contains("-seedMissed") { seedMissedDays(store: store, today: today, calendar: calendar) }
        if args.contains("-seedMissedYesterday") { seedMissedDays(store: store, today: today, calendar: calendar, missedCount: 1) }
    }

    private static func intValue(after flag: String, in args: [String]) -> Int? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return Int(args[i + 1])
    }

    /// `-seedStepsRise <from> <to> <seconds>`: the step total starts at `from` and climbs to `to` over `seconds`.
    struct StepsRise {
        let from: Int
        let to: Int
        let seconds: Double

        init?(arguments args: [String]) {
            guard args.contains("-seed"), let i = args.firstIndex(of: "-seedStepsRise"), i + 3 < args.count,
                  let from = Int(args[i + 1]), let to = Int(args[i + 2]), let seconds = Double(args[i + 3]), seconds > 0 else { return nil }
            (self.from, self.to, self.seconds) = (from, to, seconds)
        }

        func total(after elapsed: TimeInterval) -> Int {
            let fraction = min(1, max(0, elapsed / seconds))
            return from + Int((Double(to - from) * fraction).rounded())
        }

        /// Reports the rising total through `record` (the same call HealthKit updates make) until it reaches `to`.
        func run(tick: Duration = .milliseconds(250), record: @MainActor (Int) -> Void) async {
            let start = ContinuousClock.now
            while !Task.isCancelled {
                let elapsed = (ContinuousClock.now - start) / .seconds(1)
                record(total(after: elapsed))
                if elapsed >= seconds { return }
                try? await Task.sleep(for: tick)
            }
        }
    }

    /// `-seedPedometer <n>`: a `StepCounter` that reports available and counts up from `n`, so the Bypass walk shows
    /// progress on a simulator that has no motion hardware.
    static func stepCounter(arguments args: [String] = ProcessInfo.processInfo.arguments, tick: Duration = .milliseconds(500)) -> StepCounter? {
        guard args.contains("-seed"), let start = intValue(after: "-seedPedometer", in: args) else { return nil }
        return FakeStepCounter(start: start, tick: tick)
    }

    /// Counts up by one step every `tick` (about 2 steps a second by default).
    final class FakeStepCounter: StepCounter {
        private let startSteps: Int
        private let tick: Duration
        private var task: Task<Void, Never>?

        init(start: Int, tick: Duration) {
            startSteps = start
            self.tick = tick
        }

        var isAvailable: Bool { true }

        func start(onUpdate: @escaping @Sendable (Int?) -> Void) {
            task?.cancel()
            let (first, tick) = (startSteps, tick)
            task = Task {
                var steps = first
                onUpdate(steps)
                while !Task.isCancelled {
                    do { try await Task.sleep(for: tick) } catch { return }
                    steps += 1
                    onUpdate(steps)
                }
            }
        }

        func stop() {
            task?.cancel()
            task = nil
        }
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
