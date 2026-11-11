import Foundation
import Testing
@testable import LockInCore

struct TodayTests {
    let cal = calendar()

    @Test func listsDueTasksRequiredFirstThenOptional() {
        let optional = task("Stretch", requirement: .optional)
        let late = task("Gym", startTime: time(18))
        let early = task("Read")
        let notDue = task("Weekend", schedule: .weekly([.saturday]))
        let today = Today(day: day("2026-11-10"), tasks: [optional, late, notDue, early], completions: CompletionLog(), calendar: cal)
        #expect(today.required.map(\.task.title) == ["Read", "Gym"])
        #expect(today.optional.map(\.task.title) == ["Stretch"])
    }

    @Test func reportsCompletionPerDay() {
        let read = task("Read")
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-09"))
        let monday = Today(day: day("2026-11-09"), tasks: [read], completions: log, calendar: cal)
        let tuesday = Today(day: day("2026-11-10"), tasks: [read], completions: log, calendar: cal)
        #expect(monday.required.first?.isCompleted == true)
        #expect(tuesday.required.first?.isCompleted == false)
    }

    @Test func isKeptWhenAllRequiredAreDoneOrNoneAreDue() {
        let read = task("Read")
        let stretch = task("Stretch", requirement: .optional)
        var log = CompletionLog()
        let d = day("2026-11-10")
        #expect(!Today(day: d, tasks: [read, stretch], completions: log, calendar: cal).isKept)
        log.set(read.id, completed: true, on: d)
        #expect(Today(day: d, tasks: [read, stretch], completions: log, calendar: cal).isKept)
        #expect(Today(day: d, tasks: [stretch], completions: CompletionLog(), calendar: cal).isKept)
        #expect(Today(day: d, tasks: [], completions: CompletionLog(), calendar: cal).isKept)
    }

    @Test func completionLogTogglesAndPrunes() throws {
        let id = UUID()
        var log = CompletionLog()
        log.set(id, completed: true, on: day("2026-11-01"))
        log.set(id, completed: true, on: day("2026-11-10"))
        log.set(id, completed: false, on: day("2026-11-10"))
        #expect(log.isCompleted(id, on: day("2026-11-01")))
        #expect(!log.isCompleted(id, on: day("2026-11-10")))
        let pruned = log.pruned(keepingFrom: day("2026-11-02"))
        #expect(!pruned.isCompleted(id, on: day("2026-11-01")))
        let decoded = try JSONDecoder().decode(CompletionLog.self, from: JSONEncoder().encode(log))
        #expect(decoded == log)
    }
}
