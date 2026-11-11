import Foundation
import Testing
@testable import LockInCore

struct ShieldDecisionTests {
    let cal = calendar()

    func shield(_ tasks: [LockInTask], at now: Date, completions: CompletionLog = CompletionLog()) -> Bool {
        ShieldDecision.shouldShield(at: now, tasks: tasks, completions: completions, calendar: cal)
    }

    @Test func incompleteRequiredTaskWithoutStartTimeShieldsFromMidnight() {
        #expect(shield([task()], at: instant("2026-11-10", 0, 0)))
    }

    @Test func optionalTaskNeverShields() {
        #expect(!shield([task(requirement: .optional)], at: instant("2026-11-10", 12)))
    }

    @Test func requiredTaskShieldsOnlyFromItsStartTime() {
        let gym = task(startTime: time(18))
        #expect(!shield([gym], at: instant("2026-11-10", 17, 59)))
        #expect(shield([gym], at: instant("2026-11-10", 18, 0)))
    }

    @Test func completingAllRequiredTasksDropsTheShield() {
        let read = task("Read"), gym = task("Gym")
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-10"))
        #expect(shield([read, gym], at: instant("2026-11-10", 12), completions: log))
        log.set(gym.id, completed: true, on: day("2026-11-10"))
        #expect(!shield([read, gym], at: instant("2026-11-10", 12), completions: log))
    }

    @Test func noRequiredTasksDueMeansNoShield() {
        #expect(!shield([], at: instant("2026-11-10", 12)))
        #expect(!shield([task(schedule: .weekly([.saturday]))], at: instant("2026-11-10", 12)))
    }

    @Test func yesterdaysCompletionDoesNotCountToday() {
        let read = task()
        var log = CompletionLog()
        log.set(read.id, completed: true, on: day("2026-11-09"))
        #expect(shield([read], at: instant("2026-11-10", 0, 1), completions: log))
    }

    @Test func startTimeIsWallClockOnDSTDays() {
        // Spring forward in Zurich: 02:00 jumps to 03:00. A 09:00 Start Time is still 09:00.
        let t = task(startTime: time(9))
        #expect(!shield([t], at: instant("2026-03-29", 8, 59)))
        #expect(shield([t], at: instant("2026-03-29", 9, 0)))
    }
}
