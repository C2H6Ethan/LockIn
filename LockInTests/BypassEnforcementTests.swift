import DeviceActivity
import Foundation
import LockInCore
import LockInPlatform
import Testing

@MainActor
struct BypassEnforcementTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    func at(_ hour: Int, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: hour, minute: minute, second: second))!
    }

    let store = LockInStore(storage: InMemoryStorage())
    let center = FakeActivityCenter()
    let target = FakeShieldTarget()
    let poster = FakePoster()

    func enforcement() throws -> Enforcement {
        store.write([LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-01")!)], to: .tasks)
        store.write(try Fixtures.blocklist(apps: 1), to: .blocklist)
        return Enforcement(
            store: store,
            registrar: ScheduleRegistrar(center: center),
            enforcer: ShieldEnforcer(store: store, applier: ShieldApplier(target: target), calendar: calendar),
            poster: poster,
            calendar: calendar,
            source: .app
        )
    }

    @Test func startingABypassLiftsTheShieldAndSchedulesItsEnd() throws {
        let e = try enforcement()
        e.refresh(reason: "launch", now: at(15))
        #expect(target.applications != nil)

        let bypass = e.startBypass(now: at(15, 0, 30))
        #expect(target.applications == nil)
        let name = ScheduledActivity.bypassEnd(bypass.end).name
        let schedule = try #require(center.registered[name])
        #expect(!schedule.repeats)
        #expect(schedule.intervalStart.hour == 15 && schedule.intervalStart.minute == 15 && schedule.intervalStart.second == 30)
        #expect(store.read(.bypasses).usedCount(on: DayKey("2026-11-10")!, calendar: calendar) == 1)
    }

    @Test func theEndCallbackPutsTheShieldBackAndNotifies() throws {
        let e = try enforcement()
        let bypass = e.startBypass(now: at(15))
        e.intervalDidStart(activityName: ScheduledActivity.bypassEnd(bypass.end).name, now: at(15, 14, 50))  // slightly early

        #expect(target.applications != nil)
        #expect(poster.posts.map(\.title) == ["Bypass over."])
        #expect(center.registered.keys.allSatisfy { !$0.hasPrefix("bypass-end-") })
    }

    @Test func aStaleEndCallbackLeavesANewerBypassAlone() throws {
        let e = try enforcement()
        let first = e.startBypass(now: at(15))
        _ = e.startBypass(now: at(15, 5))
        e.intervalDidStart(activityName: ScheduledActivity.bypassEnd(first.end).name, now: at(15, 15))

        #expect(target.applications == nil)
        #expect(poster.posts.isEmpty)
    }

    @Test func noNotificationIfTasksWereDoneDuringTheBypass() throws {
        let e = try enforcement()
        let bypass = e.startBypass(now: at(15))
        var log = CompletionLog()
        log.set(store.read(.tasks)[0].id, completed: true, on: DayKey("2026-11-10")!)
        store.write(log, to: .completions)
        e.intervalDidStart(activityName: ScheduledActivity.bypassEnd(bypass.end).name, now: at(15, 15))

        #expect(target.applications == nil)
        #expect(poster.posts.isEmpty)
    }
}
