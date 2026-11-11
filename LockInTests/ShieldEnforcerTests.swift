import FamilyControls
import Foundation
import LockInCore
import LockInPlatform
import Testing

@MainActor
struct ShieldEnforcerTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()

    func noon() -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }

    @Test func shieldsWhenARequiredTaskIsOwed() throws {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-01")!)], to: .tasks)
        store.write(try Fixtures.blocklist(categories: 1), to: .blocklist)
        let target = FakeShieldTarget()

        let shielded = ShieldEnforcer(store: store, applier: ShieldApplier(target: target), calendar: calendar).reevaluate(now: noon())

        #expect(shielded)
        #expect(target.applicationCategories != nil)
    }

    @Test func clearsWhenNothingIsOwed() throws {
        let store = LockInStore(storage: InMemoryStorage())
        store.write(try Fixtures.blocklist(apps: 1), to: .blocklist)
        let target = FakeShieldTarget()
        target.applications = try Fixtures.blocklist(apps: 1).selection.applicationTokens

        let shielded = ShieldEnforcer(store: store, applier: ShieldApplier(target: target), calendar: calendar).reevaluate(now: noon())

        #expect(!shielded)
        #expect(target.clearCount == 1)
        #expect(target.applications == nil)
    }
}
