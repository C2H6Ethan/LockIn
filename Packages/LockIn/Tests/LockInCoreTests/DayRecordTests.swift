import Foundation
import Testing
@testable import LockInCore

struct DayRecordTests {
    let cal = calendar()

    @Test func finalizesEveryDayFromTheFirstDayThroughYesterday() {
        let read = task("Read", createdOn: "2026-11-01")
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-01"))
        let records = DayRecords.finalized(
            existing: [:], through: day("2026-11-02"), firstDay: day("2026-11-01"),
            tasks: [read], completions: log, calendar: cal
        )
        #expect(records.keys.sorted() == [day("2026-11-01"), day("2026-11-02")])
        #expect(records[day("2026-11-01")]?.outcome == .kept)
        #expect(records[day("2026-11-02")]?.outcome == .missed)
        #expect(records[day("2026-11-02")]?.requiredDue == [TaskSnapshot(id: read.id, title: "Read")])
    }

    @Test func finalizingTwiceYieldsIdenticalRecordsAndTheFirstWriterWins() {
        let read = task("Read", createdOn: "2026-11-01")
        let first = DayRecords.finalized(existing: [:], through: day("2026-11-01"), firstDay: day("2026-11-01"),
                                         tasks: [read], completions: CompletionLog(), calendar: cal)
        var renamed = read
        renamed.title = "Renamed"
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-01"))
        let second = DayRecords.finalized(existing: first, through: day("2026-11-01"), firstDay: day("2026-11-01"),
                                          tasks: [renamed], completions: log, calendar: cal)
        #expect(second == first)
        #expect(second[day("2026-11-01")]?.requiredDue.first?.title == "Read")
    }

    @Test func dayWithNoRequiredTasksIsKept() {
        let stretch = task("Stretch", requirement: .optional, createdOn: "2026-11-01")
        let records = DayRecords.finalized(existing: [:], through: day("2026-11-01"), firstDay: day("2026-11-01"),
                                           tasks: [stretch], completions: CompletionLog(), calendar: cal)
        #expect(records[day("2026-11-01")]?.outcome == .kept)
        #expect(records[day("2026-11-01")]?.requiredDue.isEmpty == true)
    }

    @Test func nothingIsFinalizedBeforeOnboarding() {
        #expect(DayRecords.finalized(existing: [:], through: day("2026-11-05"), firstDay: nil,
                                     tasks: [task()], completions: CompletionLog(), calendar: cal).isEmpty)
    }

    @Test func recordsOnlyUndoneRequiredTasksAsUndone() {
        let read = task("Read", createdOn: "2026-11-01")
        let gym = task("Gym", createdOn: "2026-11-01")
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-01"))
        let record = DayRecords.finalized(existing: [:], through: day("2026-11-01"), firstDay: day("2026-11-01"),
                                          tasks: [read, gym], completions: log, calendar: cal)[day("2026-11-01")]!
        #expect(record.undoneRequired.map(\.title) == ["Gym"])
    }
}

struct StreakTests {
    let cal = calendar()

    func streak(_ records: [DayKey: DayRecord], today: Today, firstDay: String = "2026-11-01", seed: StreakSeed? = nil) -> Int {
        Streak.current(records: records, today: today, firstDay: day(firstDay), seed: seed, calendar: cal)
    }

    func record(_ d: String, _ outcome: DayRecord.Outcome) -> (DayKey, DayRecord) {
        (day(d), DayRecord(day: day(d), requiredDue: [], completedRequired: [], outcome: outcome))
    }

    func today(_ d: String, kept: Bool) -> Today {
        let t = task(createdOn: "2026-11-01")
        var log = CompletionLog()
        if kept { log.set(t.id, completed: true, on: day(d)) }
        return Today(day: day(d), tasks: [t], completions: log, calendar: cal)
    }

    @Test func theUsersExample() {
        // Day 1 done, day 2 had no Required Tasks, day 3 done: 3 after day 3's tasks, 2 before.
        let read = task("Read", schedule: .weekly([.sunday, .tuesday]), createdOn: "2026-11-01")  // Nov 1 Sun, Nov 3 Tue
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-01"))
        let records = DayRecords.finalized(existing: [:], through: day("2026-11-02"), firstDay: day("2026-11-01"),
                                           tasks: [read], completions: log, calendar: cal)
        let before = Today(day: day("2026-11-03"), tasks: [read], completions: log, calendar: cal)
        #expect(streak(records, today: before) == 2)
        log.set(read.id, completed: true, on: day("2026-11-03"))
        let after = Today(day: day("2026-11-03"), tasks: [read], completions: log, calendar: cal)
        #expect(streak(records, today: after) == 3)
    }

    @Test func oneMissedDayResetsToZero() {
        let records = Dictionary(uniqueKeysWithValues: [record("2026-11-01", .kept), record("2026-11-02", .missed)])
        #expect(streak(records, today: today("2026-11-03", kept: false)) == 0)
        #expect(streak(records, today: today("2026-11-03", kept: true)) == 1)
    }

    @Test func frozenDaysCountAsKept() {
        let records = Dictionary(uniqueKeysWithValues: [record("2026-11-01", .kept), record("2026-11-02", .frozen)])
        #expect(streak(records, today: today("2026-11-03", kept: true)) == 3)
    }

    @Test func seedExtendsTheRunBackwards() {
        let seed = StreakSeed(count: 12, asOf: day("2026-10-31"))
        #expect(streak([:], today: today("2026-11-01", kept: true), seed: seed) == 13)
        #expect(streak([:], today: today("2026-11-01", kept: false), seed: seed) == 12)
    }

    @Test func seedIsIgnoredOnceAMissedDayBreaksTheRun() {
        let seed = StreakSeed(count: 12, asOf: day("2026-10-31"))
        let records = Dictionary(uniqueKeysWithValues: [record("2026-11-01", .missed)])
        #expect(streak(records, today: today("2026-11-02", kept: true), seed: seed) == 1)
    }

    @Test func firstDayItselfCountsOnceKept() {
        #expect(streak([:], today: today("2026-11-01", kept: false)) == 0)
        #expect(streak([:], today: today("2026-11-01", kept: true)) == 1)
    }
}
