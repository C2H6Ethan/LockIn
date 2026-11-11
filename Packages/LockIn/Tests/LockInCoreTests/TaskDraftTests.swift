import Foundation
import Testing
@testable import LockInCore

struct TaskDraftTests {
    let today = day("2026-11-10")

    func validDraft() -> TaskDraft {
        var d = TaskDraft()
        d.title = "Read"
        return d
    }

    @Test func newDraftDefaultsToRequiredEveryDayWithoutStartTime() {
        let d = TaskDraft()
        #expect(d.requirement == .required)
        #expect(d.repeats == .weekly)
        #expect(d.weekdays == Set(Weekday.allCases))
        #expect(d.startTime == nil)
    }

    @Test func validDraftHasNoErrors() {
        #expect(validDraft().validate(otherTasks: [], today: today).isEmpty)
    }

    @Test(arguments: ["", "   ", "\n"])
    func titleMustNotBeBlank(title: String) {
        var d = validDraft()
        d.title = title
        #expect(d.validate(otherTasks: [], today: today) == [.emptyTitle])
    }

    @Test func weeklyNeedsAtLeastOneWeekday() {
        var d = validDraft()
        d.weekdays = []
        #expect(d.validate(otherTasks: [], today: today) == [.noWeekdays])
        d.repeats = .once
        d.onceDay = today
        #expect(d.validate(otherTasks: [], today: today).isEmpty)
    }

    @Test func oneTimeDayMustBeTodayOrLater() {
        var d = validDraft()
        d.repeats = .once
        d.onceDay = day("2026-11-09")
        #expect(d.validate(otherTasks: [], today: today) == [.dayInPast])
        d.onceDay = today
        #expect(d.validate(otherTasks: [], today: today).isEmpty)
    }

    @Test func atMost15DistinctRequiredStartTimes() {
        let others = (0..<15).map { task("T\($0)", startTime: TimeOfDay(minutesSinceMidnight: $0 * 60)!) }
        var d = validDraft()
        d.startTime = TimeOfDay(hour: 20, minute: 15)
        #expect(d.validate(otherTasks: others, today: today) == [.tooManyStartTimes])
        d.startTime = TimeOfDay(minutesSinceMidnight: 0)  // shared with an existing Start Time
        #expect(d.validate(otherTasks: others, today: today).isEmpty)
        d.startTime = TimeOfDay(hour: 20, minute: 15)
        d.requirement = .optional                          // Optional Tasks never get an activity
        #expect(d.validate(otherTasks: others, today: today).isEmpty)
    }

    @Test func makesANewTaskCreatedToday() throws {
        var d = validDraft()
        d.title = "  Read  "
        d.weekdays = [.monday]
        d.startTime = TimeOfDay(hour: 9, minute: 0)
        let t = try #require(d.makeTask(existing: nil, today: today))
        #expect(t.title == "Read")
        #expect(t.schedule == .weekly([.monday]))
        #expect(t.startTime == TimeOfDay(hour: 9, minute: 0))
        #expect(t.createdOn == today)
    }

    @Test func editingKeepsIdentityAndCreationDay() throws {
        let original = task("Read", schedule: .weekly([.monday]), startTime: TimeOfDay(hour: 9, minute: 0), createdOn: "2026-10-01")
        var d = TaskDraft(task: original, today: today)
        #expect(d.title == "Read")
        #expect(d.weekdays == [.monday])
        d.repeats = .once
        d.onceDay = day("2026-11-12")
        d.requirement = .optional
        let edited = try #require(d.makeTask(existing: original, today: today))
        #expect(edited.id == original.id)
        #expect(edited.createdOn == day("2026-10-01"))
        #expect(edited.schedule == .once(day("2026-11-12")))
        #expect(edited.requirement == .optional)
    }

    @Test func draftRoundTripsATaskUnchanged() throws {
        let original = task("Gym", schedule: .once(day("2026-11-12")), requirement: .required, startTime: TimeOfDay(hour: 18, minute: 0))
        let again = try #require(TaskDraft(task: original, today: today).makeTask(existing: original, today: today))
        #expect(again == original)
        // Ticket 023: an Optional Task never blocks, so editing one drops its Start Time.
        let optional = task("Stretch", requirement: .optional, startTime: TimeOfDay(hour: 18, minute: 0))
        #expect(TaskDraft(task: optional, today: today).makeTask(existing: optional, today: today)?.startTime == nil)
    }

    @Test func invalidDraftMakesNoTask() {
        #expect(TaskDraft().makeTask(existing: nil, today: today) == nil)
    }
}
