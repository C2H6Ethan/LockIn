import Foundation
import Testing
@testable import LockInCore

struct StreakFreezeTests {
    let cal = calendar()

    func records(kept: [String], missed: [String]) -> [DayKey: DayRecord] {
        var r: [DayKey: DayRecord] = [:]
        for d in kept { r[day(d)] = DayRecord(day: day(d), requiredDue: [], completedRequired: [], outcome: .kept) }
        for d in missed { r[day(d)] = DayRecord(day: day(d), requiredDue: [TaskSnapshot(id: UUID(), title: "Read")], completedRequired: [], outcome: .missed) }
        return r
    }

    func recap(_ r: [DayKey: DayRecord], today: String) -> MissedDayRecap {
        MissedDayRecap.pending(records: r, today: day(today), acknowledgedThrough: nil, firstDay: day("2026-11-01"), seed: nil, calendar: cal)!
    }

    let fiveKeptThenMissed = ["2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05"]

    @Test func offeredForExactlyOneMissedDayAfterAStreak() {
        let r = recap(records(kept: fiveKeptThenMissed, missed: ["2026-11-06"]), today: "2026-11-07")
        #expect(StreakFreeze.offer(recap: r, lastUsed: nil, today: day("2026-11-07"), calendar: cal) == day("2026-11-06"))
    }

    @Test func notOfferedForTwoMissedDays() {
        let r = recap(records(kept: fiveKeptThenMissed, missed: ["2026-11-06", "2026-11-07"]), today: "2026-11-08")
        #expect(StreakFreeze.offer(recap: r, lastUsed: nil, today: day("2026-11-08"), calendar: cal) == nil)
    }

    @Test func notOfferedWithoutAStreakToSave() {
        let r = recap(records(kept: [], missed: ["2026-11-01"]), today: "2026-11-02")
        #expect(r.previousStreak == 0)
        #expect(StreakFreeze.offer(recap: r, lastUsed: nil, today: day("2026-11-02"), calendar: cal) == nil)
    }

    @Test func notOfferedTwiceInOneWeek() {
        let r = recap(records(kept: fiveKeptThenMissed, missed: ["2026-11-06"]), today: "2026-11-07")
        // 2026-11-07 is a Saturday; Monday 2026-11-02 is in the same ISO week.
        #expect(StreakFreeze.offer(recap: r, lastUsed: day("2026-11-02"), today: day("2026-11-07"), calendar: cal) == nil)
    }

    @Test func weekResetsOnMonday() {
        #expect(!StreakFreeze.isAvailable(lastUsed: day("2026-11-08"), today: day("2026-11-08"), calendar: cal))  // Sunday
        #expect(StreakFreeze.isAvailable(lastUsed: day("2026-11-08"), today: day("2026-11-09"), calendar: cal))   // Monday
        #expect(!StreakFreeze.isAvailable(lastUsed: day("2026-11-09"), today: day("2026-11-15"), calendar: cal))  // next Sunday
        #expect(StreakFreeze.isAvailable(lastUsed: nil, today: day("2026-11-09"), calendar: cal))
    }

    @Test func freezingKeepsTheStreakGoing() {
        var r = records(kept: fiveKeptThenMissed, missed: ["2026-11-06"])
        StreakFreeze.apply(to: &r, day: day("2026-11-06"))
        #expect(r[day("2026-11-06")]?.outcome == .frozen)
        // Frozen yesterday plus today kept: N + 2.
        let through = Streak.through(day("2026-11-06"), records: r, firstDay: day("2026-11-01"), seed: nil, calendar: cal)
        #expect(through == 6)
        #expect(through + 1 == 5 + 2)
        // And there is nothing left to recap.
        #expect(MissedDayRecap.pending(records: r, today: day("2026-11-07"), acknowledgedThrough: nil, firstDay: day("2026-11-01"), seed: nil, calendar: cal) == nil)
    }

    @Test func applyOnlyFreezesMissedDays() {
        var r = records(kept: ["2026-11-01"], missed: [])
        StreakFreeze.apply(to: &r, day: day("2026-11-01"))
        #expect(r[day("2026-11-01")]?.outcome == .kept)
    }
}
