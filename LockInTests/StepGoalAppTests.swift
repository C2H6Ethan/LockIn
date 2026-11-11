import Foundation
import LockInCore
import LockInPlatform
import Testing
@testable import LockIn

@MainActor
struct StepGoalAppTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 15))! }
    let walk = LockInTask(title: "Walk", schedule: .weekly(Set(Weekday.allCases)), requirement: .required,
                          createdOn: DayKey("2026-11-01")!, kind: .stepGoal(target: 8000))

    @Test func todayWontToggleAStepGoalByHand() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([walk], to: .tasks)
        var changes = 0
        let model = TodayModel(store: store, calendar: calendar, now: { now }, onChange: { changes += 1 })
        model.toggle(walk.id)
        #expect(!store.read(.completions).isCompleted(walk.id, on: DayKey("2026-11-10")!))
        #expect(changes == 0)
        #expect(model.subtitle(for: walk) == "\(8000.formatted()) steps")
    }

    @Test func stepGoalSubtitleIncludesAFutureStartTime() {
        var task = walk
        task.startTime = TimeOfDay(hour: 18, minute: 0)
        let model = TodayModel(store: LockInStore(storage: InMemoryStorage()), calendar: calendar, now: { now }, onChange: {})
        #expect(model.subtitle(for: task) == "\(8000.formatted()) steps · from 18:00")
    }

    @Test func reachingTheTargetCompletesTheTaskAndDropsTheShield() throws {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([walk], to: .tasks)
        store.write(try Fixtures.blocklist(apps: 1), to: .blocklist)
        let target = FakeShieldTarget()
        let e = Enforcement(store: store, registrar: ScheduleRegistrar(center: FakeActivityCenter()),
                            enforcer: ShieldEnforcer(store: store, applier: ShieldApplier(target: target), calendar: calendar),
                            calendar: calendar, source: .app)
        e.refresh(reason: "launch", now: now)
        #expect(target.applications != nil)

        #expect(!e.recordSteps(7999, now: now))
        #expect(e.recordSteps(8000, now: now))
        #expect(!e.recordSteps(9000, now: now))  // already done: no repeat work
        #expect(store.read(.completions).isCompleted(walk.id, on: DayKey("2026-11-10")!))
        #expect(target.applications == nil)
    }
}

@MainActor
struct StepGoalFormTests {
    @Test func importedOddTargetsStayPickable() {
        let store = LockInStore(storage: InMemoryStorage())
        let task = LockInTask(title: "Walk", schedule: .weekly(Set(Weekday.allCases)), requirement: .required,
                              createdOn: DayKey("2026-11-01")!, kind: .stepGoal(target: 7500))
        let model = TaskFormModel(editing: task, store: store, onChange: {})
        #expect(model.stepTargetChoices.contains(7500))
        #expect(model.stepTargetChoices == model.stepTargetChoices.sorted())
    }
}
