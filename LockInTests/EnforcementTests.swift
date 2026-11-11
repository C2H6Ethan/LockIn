import Foundation
import LockInCore
import LockInPlatform
import Testing

@MainActor
struct EnforcementTests {
    @Test func refreshRegistersSchedulesForStoredTasksAppliesTheShieldAndLogs() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 19))!
        let store = LockInStore(storage: InMemoryStorage())
        store.write([LockInTask(title: "Gym", schedule: .weekly(Set(Weekday.allCases)), requirement: .required,
                                startTime: TimeOfDay(hour: 18, minute: 0), createdOn: DayKey("2026-11-01")!)], to: .tasks)
        store.write(try Fixtures.blocklist(categories: 1), to: .blocklist)
        let center = FakeActivityCenter()
        let target = FakeShieldTarget()

        Enforcement(
            store: store,
            registrar: ScheduleRegistrar(center: center),
            enforcer: ShieldEnforcer(store: store, applier: ShieldApplier(target: target), calendar: calendar),
            calendar: calendar,
            source: .monitor
        ).refresh(reason: "intervalDidStart start-1800", now: now)

        #expect(Set(center.registered.keys) == ["day", "start-1800"])
        #expect(target.applicationCategories != nil)
        #expect(store.read(.eventLog).events.map(\.message) == [
            "Schedules: started day, start-1800",
            "intervalDidStart start-1800: shield up",
        ])
    }
}
