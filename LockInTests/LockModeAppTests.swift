import Foundation
import LockInCore
import LockInPlatform
import Testing
@testable import LockIn

@MainActor
struct LockModeAppTests {
    let now = Date(timeIntervalSince1970: 1_794_000_000)
    let store = LockInStore(storage: InMemoryStorage())
    let task = LockInTask(title: "Gym", schedule: .weekly([.monday, .wednesday]), requirement: .required, createdOn: DayKey("2026-11-01")!)

    init() {
        store.write([task], to: .tasks)
        var mode = LockMode()
        mode.lock(days: 7, now: now)
        store.write(mode, to: .lockMode)
    }

    func form(_ editing: LockInTask?) -> TaskFormModel {
        let now = self.now
        return TaskFormModel(editing: editing, store: store, now: { now }, onChange: {})
    }

    @Test func formRejectsWeakeningAndSaysWhy() {
        let m = form(task)
        #expect(m.lockedUntil != nil)
        m.draft.requirement = .optional
        #expect(m.lockViolations == [.makeOptional])
        #expect(!m.canSave)
        #expect(!m.save())
        #expect(store.read(.tasks)[0].requirement == .required)
    }

    @Test func formAllowsTighteningAndNewTasks() {
        let m = form(task)
        m.draft.weekdays.insert(.friday)
        #expect(m.canSave)
        #expect(m.save())

        let new = form(nil)
        new.draft.title = "Read"
        #expect(new.save())
    }

    @Test func deleteIsRefused() {
        let m = form(task)
        #expect(!m.canDelete)
        m.delete()
        #expect(store.read(.tasks).count == 1)
    }

    @Test func blocklistCanGrowButNotShrink() {
        var saved = Blocklist(customDomains: ["reddit.com"])
        store.write(saved, to: .blocklist)
        let now = self.now
        let m = BlocklistEditorModel(store: store, now: { now }, onSave: {})
        m.domainInput = "x.com"
        m.addDomain()
        #expect(m.save())
        saved = store.read(.blocklist)
        #expect(saved.customDomains == ["reddit.com", "x.com"])

        let again = BlocklistEditorModel(store: store, now: { now }, onSave: {})
        again.removeDomains(at: [0])
        #expect(again.blocklist.customDomains == ["reddit.com", "x.com"])  // refused in place
        again.blocklist.customDomains = ["x.com"]                        // e.g. via the picker
        #expect(!again.save())
        #expect(again.lockMessage != nil)
        #expect(store.read(.blocklist).customDomains == ["reddit.com", "x.com"])
    }

    @Test func settingsStartsAndExtendsButNeverEnds() {
        let fresh = LockInStore(storage: InMemoryStorage())
        let now = self.now
        let m = SettingsModel(store: fresh, now: { now }, onChange: {})
        #expect(m.lockedUntil == nil)
        m.lock(days: 3)
        #expect(m.lockedUntil == now.addingTimeInterval(3 * 86_400))
        m.lock(days: 1)
        #expect(m.lockedUntil == now.addingTimeInterval(3 * 86_400))
    }
}
