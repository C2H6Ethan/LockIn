import Foundation
import Testing
@testable import LockInCore

struct BypassTests {
    let cal = calendar()

    @Test(arguments: [(0, 100), (1, 200), (2, 300), (8, 900), (9, 1000), (10, 1000), (25, 1000)])
    func stepCost(used: Int, cost: Int) {
        #expect(BypassLog.stepCost(usedToday: used) == cost)
    }

    @Test func startingAWindowLastsFifteenMinutesAndCounts() {
        var log = BypassLog()
        let now = instant("2026-11-10", 15)
        let bypass = log.start(at: now, calendar: cal)
        #expect(bypass.end.timeIntervalSince(bypass.start) == 15 * 60)
        #expect(log.active(at: instant("2026-11-10", 15, 14)) == bypass)
        #expect(log.active(at: instant("2026-11-10", 15, 15)) == nil)
        #expect(log.usedCount(on: day("2026-11-10"), calendar: cal) == 1)
        #expect(log.nextStepCost(on: day("2026-11-10"), calendar: cal) == 200)
    }

    @Test func countResetsEachDayAndOldEntriesArePruned() {
        var log = BypassLog()
        log.start(at: instant("2026-11-09", 20), calendar: cal)
        log.start(at: instant("2026-11-09", 21), calendar: cal)
        log.start(at: instant("2026-11-11", 9), calendar: cal)
        #expect(log.usedCount(on: day("2026-11-11"), calendar: cal) == 1)
        #expect(log.bypasses.count == 1)
    }

    @Test func expiringOnlyMatchesTheCurrentWindow() {
        var log = BypassLog()
        let first = log.start(at: instant("2026-11-10", 15), calendar: cal)
        // the first window was cut short by a second Bypass started right after it (e.g. after a reinstall)
        let second = log.start(at: instant("2026-11-10", 15, 20), calendar: cal)

        let stale = log.expire(endingAt: first.end, now: instant("2026-11-10", 15, 15))
        #expect(stale == nil)
        #expect(log.active(at: instant("2026-11-10", 15, 21)) == second)

        // a callback that fires a few seconds early still ends the window
        let ended = log.expire(endingAt: second.end, now: second.end.addingTimeInterval(-5))
        #expect(ended?.id == second.id)
        #expect(log.active(at: second.end.addingTimeInterval(-4)) == nil)
    }
}

struct ShieldDecisionBypassTests {
    let cal = calendar()
    let tasks = [task("Read")]

    @Test func activeBypassLiftsTheShield() {
        var log = BypassLog()
        log.start(at: instant("2026-11-10", 15), calendar: cal)
        #expect(!ShieldDecision.shouldShield(at: instant("2026-11-10", 15, 5), tasks: tasks, completions: CompletionLog(), bypasses: log, calendar: cal))
    }

    @Test func expiredBypassDoesNot() {
        var log = BypassLog()
        log.start(at: instant("2026-11-10", 15), calendar: cal)
        #expect(ShieldDecision.shouldShield(at: instant("2026-11-10", 15, 15), tasks: tasks, completions: CompletionLog(), bypasses: log, calendar: cal))
    }
}

struct BypassActivityTests {
    @Test func bypassEndRoundTripsThroughItsName() {
        let end = Date(timeIntervalSince1970: 1_794_000_000)
        let activity = ScheduledActivity.bypassEnd(end)
        #expect(activity.name == "bypass-end-1794000000")
        #expect(ScheduledActivity(name: activity.name) == activity)
    }

    @Test func desiredIncludesAPendingBypassEnd() {
        let cal = calendar()
        var log = BypassLog()
        let bypass = log.start(at: instant("2026-11-10", 15), calendar: cal)
        let during = ScheduledActivity.desired(tasks: [], today: day("2026-11-10"), bypasses: log, now: instant("2026-11-10", 15, 1))
        #expect(during.contains(.bypassEnd(bypass.end)))
        let after = ScheduledActivity.desired(tasks: [], today: day("2026-11-10"), bypasses: log, now: bypass.end)
        #expect(after == [.day])
    }
}
