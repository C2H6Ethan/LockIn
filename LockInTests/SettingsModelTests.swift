import Foundation
import LockInCore
import Testing
@testable import LockIn

@MainActor
struct SettingsModelTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }

    func model(_ store: LockInStore, onChange: @escaping () -> Void = {}) -> SettingsModel {
        SettingsModel(store: store, calendar: calendar, now: { now }, onChange: onChange)
    }

    @Test func changingTheReminderSavesAndNotifies() {
        let store = LockInStore(storage: InMemoryStorage())
        var changes = 0
        let m = model(store, onChange: { changes += 1 })
        #expect(m.reminderTime == TimeOfDay(hour: 20, minute: 0))
        m.reminderTime = TimeOfDay(hour: 21, minute: 30)
        #expect(store.read(.settings).reminderTime == TimeOfDay(hour: 21, minute: 30))
        m.reminderTime = nil
        #expect(store.read(.settings).reminderTime == nil)
        #expect(changes == 2)
    }

    @Test func lockPreviewMatchesWhatLockingSaves() {
        let store = LockInStore(storage: InMemoryStorage())
        let m = model(store)
        let preview = m.lockedUntil(ifLockedFor: 7)
        #expect(preview == now.addingTimeInterval(7 * 86_400))
        #expect(m.lockedUntil == nil)          // previewing doesn't lock
        m.lock(days: 7)
        #expect(m.lockedUntil == preview)
        #expect(m.lockedUntil(ifLockedFor: 1) == preview)  // extending never shortens
    }
}
