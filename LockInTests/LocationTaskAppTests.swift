import Foundation
import LockInCore
import LockInPlatform
import Testing
@testable import LockIn

@MainActor
struct LocationTaskAppTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 15))! }
    let today = DayKey("2026-11-10")!
    let gym = Place(name: "Gym", latitude: 47.3769, longitude: 8.5417)
    let task: LockInTask
    let store = LockInStore(storage: InMemoryStorage())

    init() {
        task = LockInTask(title: "Gym", schedule: .weekly(Set(Weekday.allCases)), requirement: .required,
                          createdOn: DayKey("2026-11-01")!, kind: .location(Place(name: "Gym", latitude: 47.3769, longitude: 8.5417)))
        store.write([task], to: .tasks)
    }

    func model(at location: Coordinate?) -> TodayModel {
        let now = self.now
        return TodayModel(store: store, calendar: calendar, now: { now }, locate: { location }, onChange: {})
    }

    @Test func tappingAwayFromThePlaceIsRejected() async {
        let m = model(at: Coordinate(latitude: 47.40, longitude: 8.54))
        await m.toggle(task.id)?.value
        #expect(!store.read(.completions).isCompleted(task.id, on: today))
        #expect(m.message(for: task) == "Not at Gym yet today.")
    }

    @Test func tappingAtThePlaceCompletesAndRecordsTheVisit() async {
        let m = model(at: gym.coordinate)
        await m.toggle(task.id)?.value
        #expect(store.read(.completions).isCompleted(task.id, on: today))
        #expect(store.read(.visits).hasVisited(task.id, on: today))
        #expect(m.message(for: task) == nil)
    }

    @Test func anEarlierVisitTodayIsEnough() async {
        var visits = VisitLog()
        visits.record(task.id, on: today, calendar: calendar)
        store.write(visits, to: .visits)
        let m = model(at: nil)
        await m.toggle(task.id)?.value
        #expect(store.read(.completions).isCompleted(task.id, on: today))
    }

    @Test func undoingNeedsNoLocation() async {
        var log = CompletionLog()
        log.set(task.id, completed: true, on: today)
        store.write(log, to: .completions)
        let m = model(at: nil)
        await m.toggle(task.id)?.value
        #expect(!store.read(.completions).isCompleted(task.id, on: today))
    }

    @Test func rowShowsThePlace() {
        #expect(model(at: nil).subtitle(for: task) == "Gym")
    }

    @Test func enforcementRecordsVisits() {
        let e = Enforcement(store: store, registrar: ScheduleRegistrar(center: FakeActivityCenter()),
                            enforcer: ShieldEnforcer(store: store, applier: ShieldApplier(target: FakeShieldTarget()), calendar: calendar),
                            calendar: calendar, source: .app)
        e.recordVisit(task.id, now: now)
        #expect(store.read(.visits).hasVisited(task.id, on: today))
        #expect(store.read(.eventLog).events.last?.message == "Visited Gym")
    }
}
