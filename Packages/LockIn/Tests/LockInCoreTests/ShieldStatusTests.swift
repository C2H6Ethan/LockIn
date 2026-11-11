import Foundation
import Testing
@testable import LockInCore

struct ShieldStatusTests {
    let cal = calendar()
    let today = "2026-11-10"

    func status(_ tasks: [LockInTask], at now: Date, completions: CompletionLog = CompletionLog(),
                bypasses: BypassLog = BypassLog(), lockMode: LockMode = LockMode(),
                screenTimeAllowed: Bool = true, blocklistIsEmpty: Bool = false) -> ShieldStatus {
        ShieldStatus.current(now: now, tasks: tasks, completions: completions, bypasses: bypasses, lockMode: lockMode,
                             screenTimeAllowed: screenTimeAllowed, blocklistIsEmpty: blocklistIsEmpty, calendar: cal)
    }

    func done(_ tasks: LockInTask...) -> CompletionLog {
        var log = CompletionLog()
        for t in tasks { log.set(t.id, completed: true, on: day(today)) }
        return log
    }

    // MARK: States

    @Test func noRequiredTasksDue() {
        #expect(status([], at: instant(today, 12)).state == .noRequiredTasks)
        #expect(status([task(requirement: .optional)], at: instant(today, 12)).state == .noRequiredTasks)
    }

    @Test func allRequiredDoneIsOff() {
        let read = task("Read")
        #expect(status([read], at: instant(today, 12), completions: done(read)).state == .off)
    }

    @Test func owedTasksAreOnAndCountEveryIncompleteRequiredTask() {
        let read = task("Read"), gym = task("Gym", startTime: time(18)), stretch = task("Stretch", requirement: .optional)
        // Gym isn't enforced yet at noon, but it's still left to do today.
        #expect(status([read, gym, stretch], at: instant(today, 12)).state == .on(left: 2))
    }

    @Test func activeBypassResumesAtItsEnd() {
        var log = BypassLog()
        let bypass = log.start(at: instant(today, 14), calendar: cal)
        #expect(status([task()], at: instant(today, 14, 5), bypasses: log).state == .bypassed(until: bypass.end, left: 1))
    }

    @Test func expiredBypassIsOnAgain() {
        var log = BypassLog()
        log.start(at: instant(today, 14), calendar: cal)
        #expect(status([task()], at: instant(today, 14, 15), bypasses: log).state == .on(left: 1))
    }

    @Test func onlyFutureStartTimesStartAtTheEarliest() {
        let gym = task("Gym", startTime: time(23, 30)), read = task("Read", startTime: time(18))
        #expect(status([gym, read], at: instant(today, 12)).state == .startsAt(time(18), left: 2))
    }

    @Test func doneEarlyTaskDoesNotHideALaterStart() {
        let read = task("Read", startTime: time(9)), gym = task("Gym", startTime: time(23, 30))
        #expect(status([read, gym], at: instant(today, 12), completions: done(read)).state == .startsAt(time(23, 30), left: 1))
    }

    @Test func missingScreenTimeOverridesEverything() {
        let read = task()
        #expect(status([read], at: instant(today, 12), screenTimeAllowed: false).state == .needsScreenTime)
        #expect(status([], at: instant(today, 12), screenTimeAllowed: false, blocklistIsEmpty: true).state == .needsScreenTime)
        #expect(status([read], at: instant(today, 12), completions: done(read), screenTimeAllowed: false).state == .needsScreenTime)
    }

    @Test func emptyBlocklistNeedsOne() {
        #expect(status([task()], at: instant(today, 12), blocklistIsEmpty: true).state == .needsBlocklist)
    }

    @Test func lockedUntilOnlyWhileLockModeIsActive() {
        var mode = LockMode()
        mode.lock(days: 1, now: instant(today, 9))
        #expect(status([], at: instant(today, 12), lockMode: mode).lockedUntil == mode.lockedUntil)
        #expect(status([], at: instant("2026-11-11", 9, 1), lockMode: mode).lockedUntil == nil)
        #expect(status([], at: instant(today, 12)).lockedUntil == nil)
    }

    // MARK: Agrees with ShieldDecision

    @Test func isShieldUpMatchesShieldDecisionWhenSetUp() {
        let read = task("Read"), gym = task("Gym", startTime: time(18)), stretch = task("Stretch", requirement: .optional)
        var bypassed = BypassLog()
        bypassed.start(at: instant(today, 19), calendar: cal)
        let cases: [([LockInTask], Date, CompletionLog, BypassLog)] = [
            ([], instant(today, 12), CompletionLog(), BypassLog()),
            ([stretch], instant(today, 12), CompletionLog(), BypassLog()),
            ([read], instant(today, 0), CompletionLog(), BypassLog()),
            ([read], instant(today, 12), done(read), BypassLog()),
            ([gym], instant(today, 17, 59), CompletionLog(), BypassLog()),
            ([gym], instant(today, 18), CompletionLog(), BypassLog()),
            ([read, gym], instant(today, 19, 5), CompletionLog(), bypassed),
            ([read, gym], instant(today, 19, 20), CompletionLog(), bypassed),
            ([read, gym], instant(today, 19, 5), done(read, gym), bypassed),
        ]
        for (tasks, now, completions, bypasses) in cases {
            let expected = ShieldDecision.shouldShield(at: now, tasks: tasks, completions: completions, bypasses: bypasses, calendar: cal)
            #expect(status(tasks, at: now, completions: completions, bypasses: bypasses).isShieldUp == expected)
        }
    }

    // MARK: Copy

    @Test func copyForEveryState() {
        let end = instant(today, 14, 5)
        let expected: [(ShieldStatus.State, String, String?, Bool)] = [
            (.on(left: 2), "Blocking on", "2 required tasks left", false),
            (.on(left: 1), "Blocking on", "1 required task left", false),
            (.startsAt(time(23, 30), left: 1), "Blocking from 23:30", nil, false),
            (.bypassed(until: end, left: 1), "Blocking resumes at 14:05", "Bypass", false),
            (.off, "Blocking off", "Day kept", false),
            (.noRequiredTasks, "No required tasks today", nil, false),
            (.needsScreenTime, "Blocking can't start", "allow Screen Time access", true),
            (.needsBlocklist, "Nothing to block", "choose your Blocklist", true),
        ]
        for (state, lead, detail, isAction) in expected {
            let text = ShieldStatus.Text(state, calendar: cal)
            #expect(text.lead == lead)
            #expect(text.detail == detail)
            #expect(text.isAction == isAction)
            #expect(!text.lead.contains("Shield") && !(text.detail ?? "").contains("Shield"))
        }
    }
}
