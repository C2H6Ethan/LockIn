#if DEBUG
import Foundation
import LockInCore
import LockInPlatform
import Testing
@testable import LockIn

/// The Debug-only `-seed…` launch arguments (ticket 028): each goes through the real data path.
@MainActor
struct DebugSeedTests {
    let calendar = Calendar.current

    func seeded(_ arguments: String...) -> LockInStore {
        let store = LockInStore(storage: InMemoryStorage())
        DebugSeed.applyIfRequested(to: store, calendar: calendar, arguments: ["-seed"] + arguments)
        return store
    }

    func today(_ store: LockInStore) -> Today {
        Today(day: DayKey(Date(), calendar: calendar), tasks: store.read(.tasks), completions: store.read(.completions), calendar: calendar)
    }

    func entry(_ title: String, in store: LockInStore) -> Today.Entry? {
        today(store).all.first { $0.task.title == title }
    }

    // MARK: -seedSteps

    @Test func seedStepsCompletesWalkOnlyWhenTheTargetIsMet() {
        let enough = seeded("-seedSteps", "8412")
        #expect(StepGoal.progress(stored: enough.read(.stepsToday), today: DayKey(Date(), calendar: calendar)) == 8412)
        #expect(entry("Walk", in: enough)?.isCompleted == true)

        let short = seeded("-seedSteps", "5210")
        #expect(entry("Walk", in: short)?.isCompleted == false)
    }

    // MARK: -seedStepsRise

    @Test func seedStepsRiseClimbsFromTheStartTotalToTheEnd() async throws {
        let args = ["-seed", "-seedStepsRise", "7600", "8100", "2"]
        let rise = try #require(DebugSeed.StepsRise(arguments: args))
        #expect(rise.total(after: 0) == 7600)
        #expect(rise.total(after: 1) == 7850)
        #expect(rise.total(after: 5) == 8100)

        let store = LockInStore(storage: InMemoryStorage())
        DebugSeed.applyIfRequested(to: store, calendar: calendar, arguments: args)
        #expect(entry("Walk", in: store)?.isCompleted == false)

        let enforcement = Enforcement(store: store, registrar: ScheduleRegistrar(center: FakeActivityCenter()),
                                      enforcer: ShieldEnforcer(store: store, applier: ShieldApplier(target: FakeShieldTarget()), calendar: calendar),
                                      calendar: calendar, source: .app)
        // Before the end the total is below the target; after it, Walk is complete.
        _ = enforcement.recordSteps(rise.total(after: 1))
        #expect(entry("Walk", in: store)?.isCompleted == false)
        var seen: [Int] = []
        await rise.run(tick: .milliseconds(100)) { total in
            seen.append(total)
            _ = enforcement.recordSteps(total)
        }
        #expect(seen.first.map { $0 < 8000 } == true)
        #expect(seen.last == 8100)
        #expect(entry("Walk", in: store)?.isCompleted == true)
    }

    // MARK: -seedVisited

    @Test func seedVisitedMakesClimbingDueEveryDayWithTodaysVisit() throws {
        let store = seeded("-seedVisited")
        let climbing = try #require(entry("Climbing", in: store))
        let day = DayKey(Date(), calendar: calendar)
        #expect(climbing.task.isDue(on: day, calendar: calendar))
        #expect(store.read(.visits).hasVisited(climbing.task.id, on: day))
        #expect(!climbing.isCompleted)

        let done = seeded("-seedVisited", "-seedDone")
        #expect(entry("Climbing", in: done)?.isCompleted == true)
    }

    @Test func withoutSeedVisitedClimbingHasNoVisit() throws {
        let store = seeded()
        let climbing = try #require(store.read(.tasks).first { $0.title == "Climbing" })
        #expect(!store.read(.visits).hasVisited(climbing.id, on: DayKey(Date(), calendar: calendar)))
    }

    // MARK: -seedPedometer

    private final class Updates: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [Int?] = []
        func add(_ v: Int?) { lock.lock(); values.append(v); lock.unlock() }
        var all: [Int?] { lock.lock(); defer { lock.unlock() }; return values }
    }

    @Test func seedPedometerCountsUpFromTheGivenSteps() async throws {
        #expect(DebugSeed.stepCounter(arguments: ["-seed"]) == nil)
        let counter = try #require(DebugSeed.stepCounter(arguments: ["-seed", "-seedPedometer", "300"], tick: .milliseconds(10)))
        #expect(counter.isAvailable)
        let updates = Updates()
        counter.start { updates.add($0) }
        try await Task.sleep(for: .milliseconds(200))
        counter.stop()
        let values = updates.all.compactMap { $0 }
        #expect(values.first == 300)
        #expect(values.count > 2)
        #expect(values.last! > 300)
        #expect(values == values.sorted())
    }

    // MARK: -seedStreak

    @Test func seedStreakSetsTheStreakOnToday() {
        let store = seeded("-seedStreak", "30")
        let model = TodayModel(store: store, calendar: calendar, onChange: {})
        #expect(model.streak == 30)
    }
}
#endif
