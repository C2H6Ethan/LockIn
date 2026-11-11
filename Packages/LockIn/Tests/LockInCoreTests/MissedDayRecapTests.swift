import Foundation
import Testing
@testable import LockInCore

struct MissedDayRecapTests {
    let cal = calendar()

    func records(_ entries: [(String, DayRecord.Outcome, [String])]) -> [DayKey: DayRecord] {
        Dictionary(uniqueKeysWithValues: entries.map { d, outcome, undone in
            let snapshots = undone.map { TaskSnapshot(id: UUID(), title: $0) }
            return (day(d), DayRecord(day: day(d), requiredDue: snapshots, completedRequired: [], outcome: outcome))
        })
    }

    func recap(_ r: [DayKey: DayRecord], today: String, acknowledged: String? = nil, firstDay: String = "2026-11-01", seed: StreakSeed? = nil) -> MissedDayRecap? {
        MissedDayRecap.pending(records: r, today: day(today), acknowledgedThrough: acknowledged.map(day), firstDay: day(firstDay), seed: seed, calendar: cal)
    }

    @Test func nilWhenNothingWasMissedSinceTheLastAcknowledgement() {
        #expect(recap(records([("2026-11-01", .kept, [])]), today: "2026-11-02") == nil)
        let r = records([("2026-11-01", .missed, ["Read"])])
        #expect(recap(r, today: "2026-11-02", acknowledged: "2026-11-01") == nil)
    }

    @Test func listsMissedDaysNewestFirstWithSnapshotTitles() throws {
        let r = records([
            ("2026-11-01", .kept, []), ("2026-11-02", .kept, []),
            ("2026-11-03", .missed, ["Read", "Stretch"]), ("2026-11-04", .missed, ["Workout"]), ("2026-11-05", .missed, ["Read"]),
        ])
        let result = try #require(recap(r, today: "2026-11-06"))
        #expect(result.missedDays.map(\.day) == [day("2026-11-05"), day("2026-11-04"), day("2026-11-03")])
        #expect(result.missedDays.last?.undoneRequiredTaskTitles == ["Read", "Stretch"])
        #expect(result.previousStreak == 2)
        #expect(result.streakBrokenOn == day("2026-11-03"))
        #expect(!result.isTruncated)
    }

    @Test func previousStreakIsTheRunBeforeTheOldestListedMissedDay() throws {
        let r = records([
            ("2026-11-01", .kept, []), ("2026-11-02", .missed, ["A"]), ("2026-11-03", .kept, []), ("2026-11-04", .missed, ["B"]),
        ])
        let result = try #require(recap(r, today: "2026-11-05", acknowledged: "2026-11-01"))
        #expect(result.missedDays.map(\.day) == [day("2026-11-04"), day("2026-11-02")])
        #expect(result.previousStreak == 1)
        #expect(result.streakBrokenOn == day("2026-11-02"))
    }

    @Test func noStreakToLoseMeansNoBrokenDay() throws {
        let result = try #require(recap(records([("2026-11-01", .missed, ["A"])]), today: "2026-11-02"))
        #expect(result.previousStreak == 0)
        #expect(result.streakBrokenOn == nil)
    }

    @Test func importedSeedCountsTowardsThePreviousStreak() throws {
        let seed = StreakSeed(count: 12, asOf: day("2026-10-31"))
        let result = try #require(recap(records([("2026-11-01", .missed, ["A"])]), today: "2026-11-02", seed: seed))
        #expect(result.previousStreak == 12)
    }

    @Test func acknowledgingThroughADayStillSurfacesLaterMissedDays() throws {
        let r = records([("2026-11-01", .missed, ["A"]), ("2026-11-02", .missed, ["B"])])
        let result = try #require(recap(r, today: "2026-11-03", acknowledged: "2026-11-01"))
        #expect(result.missedDays.map(\.day) == [day("2026-11-02")])
    }

    @Test func frozenDaysAreNotListed() {
        #expect(recap(records([("2026-11-01", .frozen, ["A"])]), today: "2026-11-02") == nil)
    }

    @Test func lookbackIsCappedAt60Days() throws {
        var entries: [(String, DayRecord.Outcome, [String])] = []
        var d = day("2026-01-01")
        for _ in 0..<61 {
            entries.append((d.description, .missed, ["A"]))
            d = d.adding(days: 1, in: cal)
        }
        let result = try #require(recap(records(entries), today: d.description, firstDay: "2026-01-01"))
        #expect(result.missedDays.count == 60)
        #expect(result.isTruncated)
    }
}
