import Foundation
import LockInCore
import Testing
@testable import LockIn

@MainActor
struct StreakFreezeRecapTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 9))! }

    func store(missed: [String], usedOn: String? = nil) -> LockInStore {
        let store = LockInStore(storage: InMemoryStorage())
        var records: [DayKey: DayRecord] = [:]
        for d in ["2026-11-05", "2026-11-06", "2026-11-07", "2026-11-08", "2026-11-09"] where !missed.contains(d) {
            records[DayKey(d)!] = DayRecord(day: DayKey(d)!, requiredDue: [], completedRequired: [], outcome: .kept)
        }
        for d in missed {
            records[DayKey(d)!] = DayRecord(day: DayKey(d)!, requiredDue: [TaskSnapshot(id: UUID(), title: "Read")], completedRequired: [], outcome: .missed)
        }
        if missed.contains("2026-11-10") == false, records[DayKey("2026-11-10")!] == nil {
            records[DayKey("2026-11-10")!] = DayRecord(day: DayKey("2026-11-10")!, requiredDue: [TaskSnapshot(id: UUID(), title: "Read")], completedRequired: [], outcome: .missed)
        }
        store.write(records, to: .dayRecords)
        var settings = Settings(hasCompletedOnboarding: true, firstDay: DayKey("2026-11-05")!)
        settings.streakFreezeUsedOn = usedOn.flatMap(DayKey.init)
        store.write(settings, to: .settings)
        return store
    }

    @Test func offersAndSpendsAFreeze() throws {
        let store = store(missed: [])
        let m = try #require(RecapModel.pending(store: store, calendar: calendar, now: { now }))
        #expect(m.freezeLabel == "Use Streak Freeze to keep your 5\u{2011}day streak")

        m.useFreeze()
        #expect(store.read(.dayRecords)[DayKey("2026-11-10")!]?.outcome == .frozen)
        #expect(store.read(.settings).streakFreezeUsedOn == DayKey("2026-11-11"))
        #expect(RecapModel.pending(store: store, calendar: calendar, now: { now }) == nil)
    }

    @Test func noOfferWhenAlreadyUsedThisWeek() throws {
        let m = try #require(RecapModel.pending(store: store(missed: [], usedOn: "2026-11-09"), calendar: calendar, now: { now }))
        #expect(m.freezeLabel == nil)
    }

    @Test func noOfferForTwoMissedDays() throws {
        let m = try #require(RecapModel.pending(store: store(missed: ["2026-11-09"]), calendar: calendar, now: { now }))
        #expect(m.freezeLabel == nil)
    }
}
