import Foundation
import LockInCore
import Testing
@testable import LockIn

@MainActor
struct RecapModelTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 9))! }

    func day(_ s: String) -> DayKey { DayKey(s)! }

    func recap(_ days: [String], previous: Int, truncated: Bool = false) -> MissedDayRecap {
        let missed = days.map { MissedDayRecap.MissedDay(day: day($0), undoneRequiredTaskTitles: ["A", "B", "C", "D", "E", "F", "G"]) }
        return MissedDayRecap(missedDays: missed, previousStreak: previous, streakBrokenOn: previous > 0 ? missed.last?.day : nil, isTruncated: truncated)
    }

    func model(_ r: MissedDayRecap, store: LockInStore = LockInStore(storage: InMemoryStorage())) -> RecapModel {
        RecapModel(recap: r, store: store, calendar: calendar, now: { now })
    }

    @Test func headlineLeadsWithTheLostStreak() {
        let m = model(recap(["2026-11-10", "2026-11-09", "2026-11-08"], previous: 12))
        #expect(m.headline == "Your 12-day streak ended.")
        #expect(m.subline == "You missed 3 days since Sunday, Nov 8.")
    }

    @Test func singleMissedYesterday() {
        let m = model(recap(["2026-11-10"], previous: 1))
        #expect(m.headline == "Your 1-day streak ended.")
        #expect(m.subline == "You missed yesterday.")
    }

    @Test func withoutAStreakTheHeadlineNamesTheMissedDays() {
        #expect(model(recap(["2026-11-10"], previous: 0)).headline == "You missed yesterday.")
        #expect(model(recap(["2026-11-10"], previous: 0)).subline == nil)
        #expect(model(recap(["2026-11-08"], previous: 0)).headline == "You missed Sunday, Nov 8.")
        #expect(model(recap(["2026-11-10", "2026-11-09"], previous: 0)).headline == "You missed 2 days.")
    }

    @Test func dayLabels() {
        let m = model(recap(["2026-11-10"], previous: 0))
        #expect(m.label(for: day("2026-11-10")) == "YESTERDAY")
        #expect(m.label(for: day("2026-11-09")) == "MONDAY, NOV 9")
        #expect(m.label(for: day("2025-12-30")) == "TUESDAY, DEC 30, 2025")
    }

    @Test func collapsesBeyondSevenDaysAndFiveTasks() {
        let days = (1...9).map { String(format: "2026-11-%02d", 11 - $0) }
        let m = model(recap(days, previous: 0))
        #expect(m.visibleDays.count == 7)
        #expect(m.hiddenDayCount == 2)
        m.showsAllDays = true
        #expect(m.visibleDays.count == 9)
        let first = m.visibleDays[0]
        #expect(m.visibleTitles(for: first) == ["A", "B", "C", "D", "E"])
        #expect(m.hiddenTitleCount(for: first) == 2)
        m.expand(first.day)
        #expect(m.visibleTitles(for: first).count == 7)
    }

    @Test func dismissingAcknowledgesThroughTheNewestListedDay() {
        let store = LockInStore(storage: InMemoryStorage())
        model(recap(["2026-11-10", "2026-11-08"], previous: 3), store: store).acknowledge()
        #expect(store.read(.settings).recapAcknowledgedThrough == day("2026-11-10"))
    }

    @Test func pendingReadsFromTheStore() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write(Settings(hasCompletedOnboarding: true, firstDay: day("2026-11-09")), to: .settings)
        store.write([day("2026-11-09"): DayRecord(day: day("2026-11-09"), requiredDue: [TaskSnapshot(id: UUID(), title: "Read")], completedRequired: [], outcome: .missed)], to: .dayRecords)
        let pending = RecapModel.pending(store: store, calendar: calendar, now: { now })
        #expect(pending?.recap.missedDays.first?.undoneRequiredTaskTitles == ["Read"])
        pending?.acknowledge()
        #expect(RecapModel.pending(store: store, calendar: calendar, now: { now }) == nil)
    }
}
