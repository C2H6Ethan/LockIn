import Foundation
import LockInCore
import Testing
@testable import LockIn

@MainActor
struct TaskFormModelTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }

    @Test func savingANewTaskAppendsItAndNotifies() {
        let store = LockInStore(storage: InMemoryStorage())
        var changes = 0
        let model = TaskFormModel(editing: nil, store: store, calendar: calendar, now: { now }, onChange: { changes += 1 })
        #expect(!model.canSave)
        model.draft.title = "Read"
        #expect(model.canSave)
        #expect(model.save())
        #expect(store.read(.tasks).map(\.title) == ["Read"])
        #expect(store.read(.tasks).first?.createdOn == DayKey("2026-11-10"))
        #expect(changes == 1)
    }

    @Test func savingAnEditReplacesTheTaskInPlace() {
        let store = LockInStore(storage: InMemoryStorage())
        let a = LockInTask(title: "A", schedule: .weekly([.monday]), requirement: .required, createdOn: DayKey("2026-11-01")!)
        let b = LockInTask(title: "B", schedule: .weekly([.monday]), requirement: .required, createdOn: DayKey("2026-11-01")!)
        store.write([a, b], to: .tasks)
        let model = TaskFormModel(editing: a, store: store, calendar: calendar, now: { now }, onChange: {})
        model.draft.title = "A2"
        #expect(model.save())
        #expect(store.read(.tasks).map(\.title) == ["A2", "B"])
        #expect(store.read(.tasks).first?.id == a.id)
    }

    @Test func invalidDraftDoesNotSaveAndShowsErrors() {
        let store = LockInStore(storage: InMemoryStorage())
        let model = TaskFormModel(editing: nil, store: store, calendar: calendar, now: { now }, onChange: {})
        model.draft.title = "Read"
        model.draft.weekdays = []
        #expect(!model.save())
        #expect(model.errors == [.noWeekdays])
        #expect(store.read(.tasks).isEmpty)
    }

    @Test func deleteRemovesTheTaskAndNotifies() {
        let store = LockInStore(storage: InMemoryStorage())
        let a = LockInTask(title: "A", schedule: .weekly([.monday]), requirement: .required, createdOn: DayKey("2026-11-01")!)
        store.write([a], to: .tasks)
        var changes = 0
        let model = TaskFormModel(editing: a, store: store, calendar: calendar, now: { now }, onChange: { changes += 1 })
        model.delete()
        #expect(store.read(.tasks).isEmpty)
        #expect(changes == 1)
    }

    @Test func startTimeChoicesCoverEveryQuarterHourUpTo2330() {
        #expect(TaskFormModel.startTimeChoices.count == 95)
        #expect(TaskFormModel.startTimeChoices.first == TimeOfDay(hour: 0, minute: 0))
        #expect(TaskFormModel.startTimeChoices.last == TimeOfDay.latest)
    }

    @Test func saveHintSaysWhySaveIsOffFromTheStart() {
        let store = LockInStore(storage: InMemoryStorage())
        let model = TaskFormModel(editing: nil, store: store, calendar: calendar, now: { now }, onChange: {})
        #expect(model.saveHint == TaskDraft.ValidationError.emptyTitle.message)  // before any typing
        model.draft.title = "Gym"
        model.draft.completesBy = .place
        #expect(model.saveHint == "Pick a place.")
        model.draft.completesBy = .tickOff
        #expect(model.saveHint == nil)
    }

    @Test func saveHintNamesALockModeViolation() {
        let store = LockInStore(storage: InMemoryStorage())
        let read = LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-01")!)
        store.write([read], to: .tasks)
        var mode = LockMode()
        mode.lock(days: 3, now: now)
        store.write(mode, to: .lockMode)
        let model = TaskFormModel(editing: read, store: store, calendar: calendar, now: { now }, onChange: {})
        model.draft.requirement = .optional
        #expect(model.saveHint == LockPolicy.Violation.makeOptional.message)
    }
}
