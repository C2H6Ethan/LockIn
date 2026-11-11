import Foundation
import Testing
@testable import LockInCore

struct StoreWriteFailureTests {
    final class Failures: @unchecked Sendable { var keys: [String] = [] }

    @Test func anUnencodableValueIsReportedNotCrashed() {
        let failures = Failures()
        let storage = InMemoryStorage()
        let store = LockInStore(storage: storage, onWriteFailure: { key, _ in failures.keys.append(key) })
        var t = task("Gym")
        t.kind = .location(Place(name: "Gym", latitude: .nan, longitude: 8.5))  // JSON can't represent NaN

        store.write([t], to: .tasks)

        #expect(failures.keys == ["v3.tasks"])
        #expect(storage.data(forKey: "v3.tasks") == nil)  // the previous value is left as it was
    }

    @Test func aFailedWriteKeepsThePreviousValue() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([task("Read")], to: .tasks)
        var bad = task("Gym")
        bad.kind = .location(Place(name: "Gym", latitude: .infinity, longitude: 0))
        store.write([bad], to: .tasks)
        #expect(store.read(.tasks).map(\.title) == ["Read"])
    }
}

struct BypassOverNoticeTests {
    let bypass = Bypass(id: UUID(), start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 900))

    @Test func announcedOnlyWhenTheCurrentWindowEndedAndBlockingIsBack() {
        #expect(BypassLog.endNotice(ended: bypass, shieldUp: true) == Reminder.Content(title: "Bypass over.", body: "Blocking is back on."))
        #expect(BypassLog.endNotice(ended: bypass, shieldUp: false) == nil)  // Tasks were done during the Bypass
        #expect(BypassLog.endNotice(ended: nil, shieldUp: true) == nil)      // stale callback
    }
}
