import Foundation
import LockInCore
import LockInPlatform
import Testing
@testable import LockIn

/// Ticket 023: Today's blocking status line, the one success haptic, and step progress.
@MainActor
struct TodayStatusTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var noon: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }
    let today = DayKey("2026-11-10")!

    func makeTask(_ title: String, _ requirement: Requirement = .required, start: TimeOfDay? = nil, kind: LockInTask.Kind = .standard) -> LockInTask {
        LockInTask(title: title, schedule: .weekly(Set(Weekday.allCases)), requirement: requirement, startTime: start,
                   createdOn: DayKey("2026-11-01")!, kind: kind)
    }

    func model(_ store: LockInStore, screenTime: Bool = true, blocklistEmpty: Bool = false) -> TodayModel {
        TodayModel(store: store, calendar: calendar, now: { noon }, screenTimeAllowed: { screenTime },
                   blocklistIsEmpty: { blocklistEmpty }, onChange: {})
    }

    @Test func statusLineFollowsTheTasks() {
        let store = LockInStore(storage: InMemoryStorage())
        let read = makeTask("Read"), gym = makeTask("Gym")
        store.write([read, gym], to: .tasks)
        let m = model(store)
        #expect(m.status.state == .on(left: 2))
        #expect(m.statusText.lead == "Blocking on")
        m.toggle(read.id)
        #expect(m.status.state == .on(left: 1))
        m.toggle(gym.id)
        #expect(m.status.state == .off)
    }

    @Test func statusLineTakesScreenTimeAndBlocklistFromThePlatform() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([makeTask("Read")], to: .tasks)
        #expect(model(store, screenTime: false).status.state == .needsScreenTime)
        #expect(model(store, blocklistEmpty: true).status.state == .needsBlocklist)
    }

    @Test func onlyTheTickThatTurnsBlockingOffCountsAsADrop() {
        let store = LockInStore(storage: InMemoryStorage())
        let read = makeTask("Read"), gym = makeTask("Gym"), stretch = makeTask("Stretch", .optional)
        let later = makeTask("Late", start: TimeOfDay(hour: 23, minute: 0))
        store.write([read, gym, stretch, later], to: .tasks)
        let m = model(store)

        m.toggle(read.id)
        #expect(m.shieldDrops == 0)      // Gym still owed
        m.toggle(stretch.id)
        #expect(m.shieldDrops == 0)      // Optional Tasks never block
        m.toggle(gym.id)
        #expect(m.shieldDrops == 1)      // nothing owed now: blocking is off until 23:00
        m.toggle(gym.id)
        #expect(m.shieldDrops == 1)      // un-ticking never counts
        m.toggle(gym.id)
        #expect(m.shieldDrops == 2)
    }

    @Test func stepGoalSubtitleShowsTodaysProgressWhenKnown() {
        let store = LockInStore(storage: InMemoryStorage())
        let walk = makeTask("Walk", kind: .stepGoal(target: 8000))
        let m = model(store)
        #expect(m.subtitle(for: walk) == "\(8000.formatted()) steps")
        store.write(StepsToday(day: today, total: 5210), to: .stepsToday)
        m.reload()
        #expect(m.subtitle(for: walk) == "\(5210.formatted()) of \(8000.formatted()) steps")
        #expect(m.stepProgress(for: walk) == 5210.0 / 8000.0)
    }

    @Test func recordingStepsSavesTodaysTotalEvenBelowTheGoal() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([makeTask("Walk", kind: .stepGoal(target: 8000))], to: .tasks)
        let e = Enforcement(store: store, registrar: ScheduleRegistrar(center: FakeActivityCenter()),
                            enforcer: ShieldEnforcer(store: store, applier: ShieldApplier(target: FakeShieldTarget()), calendar: calendar),
                            calendar: calendar, source: .app)
        #expect(!e.recordSteps(4000, now: noon))
        #expect(store.read(.stepsToday) == StepsToday(day: today, total: 4000))
    }
}

/// Ticket 023: the Tasks screen (moved out of Settings).
@MainActor
struct TasksModelTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }

    func makeTask(_ title: String, _ schedule: Schedule, _ requirement: Requirement = .required, start: TimeOfDay? = nil,
                  kind: LockInTask.Kind = .standard) -> LockInTask {
        LockInTask(title: title, schedule: schedule, requirement: requirement, startTime: start, createdOn: DayKey("2026-11-01")!, kind: kind)
    }

    func model(_ store: LockInStore) -> TasksModel { TasksModel(store: store, calendar: calendar, now: { now }) }

    @Test func listsAllTasksRequiredFirstIncludingOnesNotDueToday() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([
            makeTask("Stretch", .weekly(Set(Weekday.allCases)), .optional),
            makeTask("Weekend run", .weekly([.saturday, .sunday])),
            makeTask("Read", .weekly(Set(Weekday.allCases))),
            makeTask("Old", .once(DayKey("2026-11-02")!)),
        ], to: .tasks)
        let m = model(store)
        #expect(m.list.required.map(\.title) == ["Read", "Weekend run", "Old"])
        #expect(m.list.optional.map(\.title) == ["Stretch"])
    }

    @Test func describesSchedulesKindsAndStartTimes() {
        let m = model(LockInStore(storage: InMemoryStorage()))
        let every = Schedule.weekly(Set(Weekday.allCases))
        #expect(m.describe(makeTask("A", every)) == "Every day")
        #expect(m.describe(makeTask("A", .weekly([.monday, .tuesday, .wednesday, .thursday, .friday]))) == "Weekdays")
        #expect(m.describe(makeTask("A", .weekly([.saturday, .sunday]))) == "Weekends")
        #expect(m.describe(makeTask("A", .weekly([.friday, .monday, .wednesday]))) == "Mon, Wed, Fri")
        #expect(m.describe(makeTask("A", .once(DayKey("2026-11-12")!), start: TimeOfDay(hour: 18, minute: 0))) == "Thu, Nov 12 · blocks from 18:00")
        #expect(m.describe(makeTask("A", .once(DayKey("2026-11-10")!))) == "Today")
        #expect(m.describe(makeTask("A", every, kind: .stepGoal(target: 8000))) == "Every day · \(8000.formatted()) steps")
        #expect(m.describe(makeTask("A", every, kind: .location(Place(name: "Gym", latitude: 0, longitude: 0)))) == "Every day · Gym")
        // Optional Tasks never block, so a leftover Start Time isn't shown.
        #expect(m.describe(makeTask("A", every, .optional, start: TimeOfDay(hour: 18, minute: 0))) == "Every day")
    }
}
