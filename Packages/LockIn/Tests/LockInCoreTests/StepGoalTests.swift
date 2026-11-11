import Foundation
import Testing
@testable import LockInCore

struct StepGoalTests {
    let cal = calendar()
    let today = day("2026-11-10")  // a Tuesday

    func stepTask(_ target: Int, schedule: Schedule = .weekly(Set(Weekday.allCases))) -> LockInTask {
        var t = task("Walk", schedule: schedule)
        t.kind = .stepGoal(target: target)
        return t
    }

    @Test func completesDueStepGoalsWhoseTargetIsReached() {
        let reached = stepTask(5000)
        let notYet = stepTask(9000)
        let notDue = stepTask(100, schedule: .weekly([.monday]))
        let manual = task("Read")
        let done = StepGoal.completions(tasks: [reached, notYet, notDue, manual], stepsToday: 6000, day: today, calendar: cal)
        #expect(done == [reached.id])
    }

    @Test func exactlyTheTargetCounts() {
        let t = stepTask(5000)
        #expect(StepGoal.completions(tasks: [t], stepsToday: 5000, day: today, calendar: cal) == [t.id])
        #expect(StepGoal.completions(tasks: [t], stepsToday: 4999, day: today, calendar: cal).isEmpty)
    }

    @Test func stepGoalsCantBeCompletedByHand() {
        #expect(!stepTask(5000).canCompleteManually)
        #expect(task("Read").canCompleteManually)
    }

    @Test func tasksStoredWithoutAKindDecodeAsStandard() throws {
        let original = task("Read")
        var json = String(decoding: try JSONEncoder().encode(original), as: UTF8.self)
        json = json.replacingOccurrences(of: #","kind":{"standard":{}}"#, with: "")
            .replacingOccurrences(of: #""kind":{"standard":{}},"#, with: "")
        #expect(!json.contains("kind"))
        let decoded = try JSONDecoder().decode(LockInTask.self, from: Data(json.utf8))
        #expect(decoded == original)
    }

    @Test func kindRoundTrips() throws {
        let t = stepTask(7500)
        #expect(try JSONDecoder().decode(LockInTask.self, from: JSONEncoder().encode(t)) == t)
    }
}

struct StepGoalDraftTests {
    let today = day("2026-11-10")

    @Test func draftMakesAStepGoalTask() {
        var d = TaskDraft()
        d.title = "Walk"
        d.completesBy = .steps
        d.stepTarget = 8000
        #expect(d.makeTask(existing: nil, today: today)?.kind == .stepGoal(target: 8000))
    }

    @Test(arguments: [0, 99, 100_001])
    func targetOutOfRangeIsInvalid(target: Int) {
        var d = TaskDraft()
        d.title = "Walk"
        d.completesBy = .steps
        d.stepTarget = target
        #expect(d.validate(otherTasks: [], today: today) == [.invalidStepTarget])
    }

    @Test func editingKeepsTheTarget() {
        var t = task("Walk")
        t.kind = .stepGoal(target: 6000)
        #expect(TaskDraft(task: t, today: today).stepTarget == 6000)
        #expect(TaskDraft(task: task("Read"), today: today).completesBy == .tapping)
    }
}

/// Ticket 023: Today shows "5,210 of 8,000 steps" from the last total the app read, or just the target when unknown.
struct StepProgressTests {
    let today = day("2026-11-10")

    @Test func todaysTotalIsKnown() {
        #expect(StepGoal.progress(stored: StepsToday(day: today, total: 5210), today: today) == 5210)
    }

    @Test func nothingReadOrAnotherDayIsUnknown() {
        #expect(StepGoal.progress(stored: nil, today: today) == nil)
        #expect(StepGoal.progress(stored: StepsToday(day: day("2026-11-09"), total: 9000), today: today) == nil)
    }

    @Test func storedTotalRoundTrips() throws {
        let stored = StepsToday(day: today, total: 5210)
        #expect(try JSONDecoder().decode(StepsToday.self, from: JSONEncoder().encode(stored)) == stored)
        #expect(Document<StepsToday?>.stepsToday.key == "v3.stepsToday")
    }
}
