import Foundation
import Testing
@testable import LockInCore

struct WidgetSnapshotTests {
    let cal = calendar()

    @Test func countsRequiredProgressStreakAndUndoneTitles() {
        let read = task("Read"), gym = task("Gym"), walk = task("Walk"), stretch = task("Stretch", requirement: .optional)
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-10"))
        let records = [day("2026-11-09"): DayRecord(day: day("2026-11-09"), requiredDue: [], completedRequired: [], outcome: .kept)]

        let s = WidgetSnapshot.make(tasks: [read, gym, walk, stretch], completions: log, records: records,
                                    settings: Settings(firstDay: day("2026-11-09")), now: instant("2026-11-10", 12), calendar: cal)
        #expect(s.requiredDone == 1)
        #expect(s.requiredTotal == 3)
        #expect(s.undoneRequiredTitles == ["Gym", "Walk"])
        #expect(s.streak == 1)          // yesterday kept; today not yet
        #expect(!s.isKept)
    }

    @Test func keptTodayCountsTowardTheStreak() {
        let read = task("Read")
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-10"))
        let s = WidgetSnapshot.make(tasks: [read], completions: log, records: [:], settings: Settings(firstDay: day("2026-11-10")),
                                    now: instant("2026-11-10", 12), calendar: cal)
        #expect(s.isKept)
        #expect(s.streak == 1)
    }

    @Test func refreshTimesAreUpcomingStartTimesAndMidnight() {
        let a = task("A", startTime: time(9)), b = task("B", startTime: time(18)), c = task("C", startTime: time(18))
        let times = WidgetSnapshot.refreshDates(tasks: [a, b, c], now: instant("2026-11-10", 12), calendar: cal)
        #expect(times == [instant("2026-11-10", 18), instant("2026-11-11", 0)])
    }
}
