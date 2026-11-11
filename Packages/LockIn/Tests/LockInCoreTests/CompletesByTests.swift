import Foundation
import Testing
@testable import LockInCore

/// Ticket 023: "Completes by" is one choice (Tapping, Steps, Place) that maps 1:1 onto `LockInTask.Kind`.
struct CompletesByTests {
    let today = day("2026-11-10")
    let gym = Place(name: "Gym", latitude: 47.37, longitude: 8.54)

    func draft(_ completesBy: TaskDraft.CompletesBy) -> TaskDraft {
        var d = TaskDraft()
        d.title = "Task"
        d.completesBy = completesBy
        return d
    }

    @Test func newDraftCompletesByTapping() {
        #expect(TaskDraft().completesBy == .tapping)
        #expect(TaskDraft().stepTarget == TaskDraft.defaultStepTarget)
    }

    @Test func eachChoiceMakesItsKind() {
        #expect(draft(.tapping).makeTask(existing: nil, today: today)?.kind == .standard)
        var steps = draft(.steps)
        steps.stepTarget = 6000
        #expect(steps.makeTask(existing: nil, today: today)?.kind == .stepGoal(target: 6000))
        var place = draft(.place)
        place.place = gym
        #expect(place.makeTask(existing: nil, today: today)?.kind == .location(gym))
    }

    @Test func valuesOfTheOtherChoicesAreIgnored() {
        // Switching back to Tapping after picking a place and a target leaves a plain Task, not an invalid one.
        var d = draft(.tapping)
        d.stepTarget = 5000
        d.place = gym
        #expect(d.validate(otherTasks: [], today: today).isEmpty)
        #expect(d.makeTask(existing: nil, today: today)?.kind == .standard)
    }

    @Test func placeChoiceNeedsAPlace() {
        #expect(draft(.place).validate(otherTasks: [], today: today) == [.noPlace])
        #expect(TaskDraft.ValidationError.noPlace.message == "Pick a place.")
    }

    @Test(arguments: [LockInTask.Kind.standard, .stepGoal(target: 7000), .location(Place(name: "Gym", latitude: 47.37, longitude: 8.54))])
    func editingRoundTripsTheKind(kind: LockInTask.Kind) {
        var t = task("Task")
        t.kind = kind
        let d = TaskDraft(task: t, today: today)
        #expect(d.makeTask(existing: t, today: today)?.kind == kind)
    }

    @Test func editingSetsTheChoice() {
        var t = task("Walk")
        t.kind = .stepGoal(target: 7000)
        #expect(TaskDraft(task: t, today: today).completesBy == .steps)
        #expect(TaskDraft(task: t, today: today).stepTarget == 7000)
        t.kind = .location(gym)
        #expect(TaskDraft(task: t, today: today).completesBy == .place)
        #expect(TaskDraft(task: task("Read"), today: today).completesBy == .tapping)
    }

    @Test func optionalTasksSaveWithoutAStartTime() {
        var d = draft(.tapping)
        d.requirement = .optional
        d.startTime = time(18)
        #expect(d.makeTask(existing: nil, today: today)?.startTime == nil)
        d.requirement = .required
        #expect(d.makeTask(existing: nil, today: today)?.startTime == time(18))
    }
}

/// Ticket 023: the Tasks screen's order, moved out of `SettingsModel`.
struct TaskListTests {
    let today = day("2026-11-10")

    @Test func requiredThenOptionalByTitleWithPastOneTimeTasksLast() {
        let gym = task("gym"), read = task("Read")
        let dentist = task("Dentist", schedule: .once(day("2026-11-09")))
        let party = task("Party", schedule: .once(day("2026-11-12")))
        let stretch = task("Stretch", requirement: .optional), journal = task("Journal", requirement: .optional)
        let oldNote = task("Call", schedule: .once(day("2026-11-01")), requirement: .optional)

        let list = TaskList(tasks: [stretch, dentist, read, oldNote, gym, party, journal], today: today)
        #expect(list.required.map(\.title) == ["gym", "Party", "Read", "Dentist"])
        #expect(list.optional.map(\.title) == ["Journal", "Stretch", "Call"])
        #expect(list.isPast(dentist) && !list.isPast(party) && !list.isPast(read))
    }

    @Test func todaysOneTimeTaskIsNotPast() {
        let t = task("Today", schedule: .once(day("2026-11-10")))
        #expect(!TaskList(tasks: [t], today: today).isPast(t))
    }
}
