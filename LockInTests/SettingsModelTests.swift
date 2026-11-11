import Foundation
import LockInCore
import Testing
@testable import LockIn

@MainActor
struct SettingsModelTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }

    func makeTask(_ title: String, _ schedule: Schedule, _ requirement: Requirement = .required, start: TimeOfDay? = nil) -> LockInTask {
        LockInTask(title: title, schedule: schedule, requirement: requirement, startTime: start, createdOn: DayKey("2026-11-01")!)
    }

    func model(_ store: LockInStore, onChange: @escaping () -> Void = {}) -> SettingsModel {
        SettingsModel(store: store, calendar: calendar, now: { now }, onChange: onChange)
    }

    @Test func changingTheReminderSavesAndNotifies() {
        let store = LockInStore(storage: InMemoryStorage())
        var changes = 0
        let m = model(store, onChange: { changes += 1 })
        #expect(m.reminderTime == TimeOfDay(hour: 20, minute: 0))
        m.reminderTime = TimeOfDay(hour: 21, minute: 30)
        #expect(store.read(.settings).reminderTime == TimeOfDay(hour: 21, minute: 30))
        m.reminderTime = nil
        #expect(store.read(.settings).reminderTime == nil)
        #expect(changes == 2)
    }

    @Test func listsAllTasksRequiredFirstIncludingOnesNotDueToday() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([
            makeTask("Stretch", .weekly(Set(Weekday.allCases)), .optional),
            makeTask("Weekend run", .weekly([.saturday, .sunday])),
            makeTask("Read", .weekly(Set(Weekday.allCases))),
        ], to: .tasks)
        let m = model(store)
        #expect(m.requiredTasks.map(\.title) == ["Read", "Weekend run"])
        #expect(m.optionalTasks.map(\.title) == ["Stretch"])
    }

    @Test func describesSchedules() {
        let m = model(LockInStore(storage: InMemoryStorage()))
        #expect(m.describe(makeTask("A", .weekly(Set(Weekday.allCases)))) == "Every day")
        #expect(m.describe(makeTask("A", .weekly([.monday, .tuesday, .wednesday, .thursday, .friday]))) == "Weekdays")
        #expect(m.describe(makeTask("A", .weekly([.saturday, .sunday]))) == "Weekends")
        #expect(m.describe(makeTask("A", .weekly([.friday, .monday, .wednesday]))) == "Mon, Wed, Fri")
        #expect(m.describe(makeTask("A", .once(DayKey("2026-11-12")!), start: TimeOfDay(hour: 18, minute: 0))) == "Thu, Nov 12 · from 18:00")
        #expect(m.describe(makeTask("A", .once(DayKey("2026-11-10")!))) == "Today")
    }

    @Test func pastOneTimeTasksAreListedLast() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([
            makeTask("Old", .once(DayKey("2026-11-02")!)),
            makeTask("Read", .weekly(Set(Weekday.allCases))),
        ], to: .tasks)
        #expect(model(store).requiredTasks.map(\.title) == ["Read", "Old"])
    }
}
