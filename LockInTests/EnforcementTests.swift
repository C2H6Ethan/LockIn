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

@MainActor
struct EnforcementDayRecordTests {
    @Test func refreshFinalizesDaysThatEndedAndLogsThem() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 0))!
        let store = LockInStore(storage: InMemoryStorage())
        let read = LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-10")!)
        store.write([read], to: .tasks)
        var log = CompletionLog()
        log.set(read.id, completed: true, on: DayKey("2026-11-10")!)
        store.write(log, to: .completions)
        store.write(Settings(hasCompletedOnboarding: true, firstDay: DayKey("2026-11-10")!), to: .settings)

        Enforcement(
            store: store,
            registrar: ScheduleRegistrar(center: FakeActivityCenter()),
            enforcer: ShieldEnforcer(store: store, applier: ShieldApplier(target: FakeShieldTarget()), calendar: calendar),
            calendar: calendar,
            source: .monitor
        ).refresh(reason: "intervalDidStart day", now: midnight)

        let records = store.read(.dayRecords)
        #expect(records[DayKey("2026-11-10")!]?.outcome == .kept)
        #expect(records[DayKey("2026-11-11")!]?.outcome == .missed)
        #expect(store.read(.eventLog).events.contains { $0.message == "Finalized 2026-11-10 kept, 2026-11-11 missed" })
    }
}
