import Foundation
import LockInCore
import LockInPlatform
import Testing
@testable import LockIn

final class FakeStepCounter: StepCounter, @unchecked Sendable {
    var isAvailable = true
    var onUpdate: (@Sendable (Int?) -> Void)?
    var stopped = false
    func start(onUpdate: @escaping @Sendable (Int?) -> Void) { self.onUpdate = onUpdate }
    func stop() { stopped = true }
}

@MainActor
struct BypassModelTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 15))! }

    func model(owed: Bool = true, log: BypassLog = BypassLog(), counter: FakeStepCounter = FakeStepCounter(), started: @escaping () -> Void = {}) -> BypassModel {
        let store = LockInStore(storage: InMemoryStorage())
        if owed {
            store.write([LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-01")!)], to: .tasks)
        }
        store.write(log, to: .bypasses)
        let calendar = self.calendar
        let now = self.now
        return BypassModel(store: store, counter: counter, calendar: calendar, now: { now }, startBypass: {
            started()
            var log = store.read(.bypasses)
            let bypass = log.start(at: now, calendar: calendar)
            store.write(log, to: .bypasses)
            return bypass
        })
    }

    @Test func walkingReachesTheGoalAndStartsABypass() {
        let counter = FakeStepCounter()
        var starts = 0
        let m = model(counter: counter, started: { starts += 1 })
        m.appear()
        #expect(m.state == .walking(steps: 0, goal: 100))
        m.receive(steps: 40)
        #expect(m.state == .walking(steps: 40, goal: 100))
        #expect(m.status == "Keep going.")
        m.receive(steps: 100)
        m.receive(steps: 104)  // late updates don't start a second one
        #expect(starts == 1)
        #expect(m.state == .active(until: now.addingTimeInterval(15 * 60)))
        #expect(counter.stopped)
    }

    @Test func secondBypassOfTheDayCostsMore() {
        var log = BypassLog()
        log.start(at: now.addingTimeInterval(-3600), calendar: calendar)
        let m = model(log: log)
        m.appear()
        #expect(m.state == .walking(steps: 0, goal: 200))
    }

    @Test func nothingOwedNeedsNoWalk() {
        let m = model(owed: false)
        m.appear()
        #expect(m.state == .nothingOwed)
    }

    @Test func anActiveBypassIsShownInsteadOfANewWalk() {
        var log = BypassLog()
        let bypass = log.start(at: now.addingTimeInterval(-60), calendar: calendar)
        let m = model(log: log)
        m.appear()
        #expect(m.state == .active(until: bypass.end))
    }

    @Test func deniedMotionExplainsItself() {
        let m = model()
        m.appear()
        m.receive(steps: nil)
        #expect(m.state == .motionDenied)
    }

    @Test func noPedometerMeansUnavailable() {
        let counter = FakeStepCounter()
        counter.isAvailable = false
        let m = model(counter: counter)
        m.appear()
        #expect(m.state == .unavailable)
    }
}
