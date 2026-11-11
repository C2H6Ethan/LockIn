import Foundation
import Testing
@testable import LockInCore

struct EventLogTests {
    @Test func keepsTheNewest200Events() {
        var log = EventLog()
        for i in 0..<250 { log.append(Event(date: Date(timeIntervalSince1970: Double(i)), source: .app, message: "\(i)")) }
        #expect(log.events.count == 200)
        #expect(log.events.first?.message == "50")
        #expect(log.events.last?.message == "249")
    }

    @Test func storeAppendsThroughTheDocument() {
        let store = LockInStore(storage: InMemoryStorage())
        store.log("first", source: .monitor, at: Date(timeIntervalSince1970: 1))
        store.log("second", source: .app, at: Date(timeIntervalSince1970: 2))
        #expect(store.read(.eventLog).events.map(\.message) == ["first", "second"])
        #expect(store.read(.eventLog).events.map(\.source) == [.monitor, .app])
    }

    @Test func corruptDocumentsAreLoggedByTheStoreItself() {
        let storage = InMemoryStorage()
        storage.set(Data("garbage".utf8), forKey: Document.tasks.key)
        let store = LockInStore.logging(storage: storage, source: .monitor)
        _ = store.read(.tasks)
        #expect(store.read(.eventLog).events.last?.message.hasPrefix("Corrupt v3.tasks") == true)
    }
}
