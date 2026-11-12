import Foundation
import LockInCore
import Testing
@testable import LockIn

@MainActor
struct TodayModelTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()

    func at(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func makeTask(_ title: String, _ requirement: Requirement = .required, start: TimeOfDay? = nil) -> LockInTask {
        LockInTask(title: title, schedule: .weekly(Set(Weekday.allCases)), requirement: requirement, startTime: start, createdOn: DayKey("2026-11-01")!)
    }

    @Test func showsTodaysTasksRequiredThenOptional() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([makeTask("Stretch", .optional), makeTask("Read")], to: .tasks)
        let model = TodayModel(store: store, calendar: calendar, now: { at(10, 9) }, onChange: {})
        #expect(model.today.required.map(\.task.title) == ["Read"])
        #expect(model.today.optional.map(\.task.title) == ["Stretch"])
    }

    @Test func togglingPersistsTheCompletionAndNotifies() {
        let store = LockInStore(storage: InMemoryStorage())
        let read = makeTask("Read")
        store.write([read], to: .tasks)
        var changes = 0
        let model = TodayModel(store: store, calendar: calendar, now: { at(10, 9) }, onChange: { changes += 1 })

        model.toggle(read.id)
        #expect(store.read(.completions).isCompleted(read.id, on: DayKey("2026-11-10")!))
        #expect(model.today.required.first?.isCompleted == true)
        #expect(changes == 1)

        model.toggle(read.id)
        #expect(!store.read(.completions).isCompleted(read.id, on: DayKey("2026-11-10")!))
        #expect(changes == 2)
    }

    @Test func reloadMovesToTheNewDay() {
        let store = LockInStore(storage: InMemoryStorage())
        let read = makeTask("Read")
        store.write([read], to: .tasks)
        var now = at(10, 23)
        let model = TodayModel(store: store, calendar: calendar, now: { now }, onChange: {})
        model.toggle(read.id)
        now = at(11, 0)
        model.reload()
        #expect(model.today.day == DayKey("2026-11-11")!)
        #expect(model.today.required.first?.isCompleted == false)
    }

    @Test func subtitleShowsOnlyFutureStartTimes() {
        let store = LockInStore(storage: InMemoryStorage())
        let model = TodayModel(store: store, calendar: calendar, now: { at(10, 12) }, onChange: {})
        #expect(model.subtitle(for: makeTask("Gym", start: TimeOfDay(hour: 18, minute: 0))) == "blocks from 18:00")
        #expect(model.subtitle(for: makeTask("Read", start: TimeOfDay(hour: 9, minute: 0))) == nil)
        #expect(model.subtitle(for: makeTask("Walk")) == nil)
        #expect(model.subtitle(for: makeTask("Stretch", .optional, start: TimeOfDay(hour: 18, minute: 0))) == nil)
    }

    @Test func headerNamesTheDay() {
        let model = TodayModel(store: LockInStore(storage: InMemoryStorage()), calendar: calendar, now: { at(10, 12) }, onChange: {})
        #expect(model.dateHeader == "Tuesday, Nov 10")
    }
}

@MainActor
struct TodayStreakTests {
    @Test func streakIncludesTodayOnceKept() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 12))!
        let store = LockInStore(storage: InMemoryStorage())
        let read = LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-10")!)
        store.write([read], to: .tasks)
        store.write(Settings(hasCompletedOnboarding: true, firstDay: DayKey("2026-11-10")!), to: .settings)
        store.write([DayKey("2026-11-10")!: DayRecord(day: DayKey("2026-11-10")!, requiredDue: [], completedRequired: [], outcome: .kept)], to: .dayRecords)
        let model = TodayModel(store: store, calendar: calendar, now: { now }, onChange: {})
        #expect(model.streakLabel == "1-day streak")
        model.toggle(read.id)
        #expect(model.streakLabel == "2-day streak")
    }
}
