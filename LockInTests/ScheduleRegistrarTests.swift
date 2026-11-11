import DeviceActivity
import Foundation
import LockInCore
import LockInPlatform
import Testing

@MainActor
struct ScheduleRegistrarTests {
    func time(_ h: Int, _ m: Int = 0) -> TimeOfDay { TimeOfDay(hour: h, minute: m)! }

    @Test func startsMissingActivities() {
        let center = FakeActivityCenter()
        let report = ScheduleRegistrar(center: center).sync(desired: [.day, .start(time(18))])
        #expect(Set(center.registered.keys) == ["day", "start-1800"])
        #expect(report.started == ["day", "start-1800"])
        #expect(report.failures.isEmpty)
    }

    @Test func stopsStaleActivitiesIncludingV2Leftovers() {
        let center = FakeActivityCenter()
        center.registered = [
            "day": ScheduleRegistrar.schedule(for: .day),
            "start-0900": ScheduleRegistrar.schedule(for: .start(time(9))),
            "com.ethanbaumgartner.lockin.daily": ScheduleRegistrar.schedule(for: .day),
        ]
        let report = ScheduleRegistrar(center: center).sync(desired: [.day])
        #expect(Set(center.registered.keys) == ["day"])
        #expect(report.stopped == ["com.ethanbaumgartner.lockin.daily", "start-0900"])
    }

    @Test func secondSyncWithNoChangesDoesNothing() {
        let center = FakeActivityCenter()
        let registrar = ScheduleRegistrar(center: center)
        registrar.sync(desired: [.day, .start(time(9))])
        center.calls = 0
        let report = registrar.sync(desired: [.day, .start(time(9))])
        #expect(center.calls == 0)
        #expect(report.isEmpty)
    }

    @Test func reRegistersActivitiesTheOSDropped() {
        // The v2 bug: a saved "already registered" flag hid the fact that iOS had dropped the monitor.
        let center = FakeActivityCenter()
        let registrar = ScheduleRegistrar(center: center)
        registrar.sync(desired: [.day])
        center.registered = [:]
        registrar.sync(desired: [.day])
        #expect(Set(center.registered.keys) == ["day"])
    }

    @Test func aFailureIsReportedAndTheRestStillRegister() {
        let center = FakeActivityCenter()
        center.failingNames = ["start-0900"]
        let report = ScheduleRegistrar(center: center).sync(desired: [.day, .start(time(9)), .start(time(18))])
        #expect(Set(center.registered.keys) == ["day", "start-1800"])
        #expect(report.failures.map(\.name) == ["start-0900"])
    }

    @Test func schedulesRepeatDailyFromStartToEndOfDay() {
        let day = ScheduleRegistrar.schedule(for: .day)
        #expect(day.intervalStart == DateComponents(hour: 0, minute: 0))
        #expect(day.intervalEnd == DateComponents(hour: 23, minute: 59))
        #expect(day.repeats)
        #expect(day.warningTime == nil)
        let start = ScheduleRegistrar.schedule(for: .start(time(18, 15)))
        #expect(start.intervalStart == DateComponents(hour: 18, minute: 15))
        #expect(start.intervalEnd == DateComponents(hour: 23, minute: 59))
        #expect(start.repeats)
    }
}

final class FakeActivityCenter: ActivityCenter {
    var registered: [String: DeviceActivitySchedule] = [:]
    var failingNames: Set<String> = []
    var calls = 0

    var activityNames: [String] { Array(registered.keys) }

    func startMonitoring(_ name: String, during schedule: DeviceActivitySchedule) throws {
        calls += 1
        if failingNames.contains(name) { throw DeviceActivityCenter.MonitoringError.intervalTooShort }
        registered[name] = schedule
    }

    func stopMonitoring(_ names: [String]) {
        calls += 1
        for name in names { registered[name] = nil }
    }
}
