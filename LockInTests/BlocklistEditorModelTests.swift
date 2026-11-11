import Foundation
import LockInCore
import LockInPlatform
import Testing
@testable import LockIn

@MainActor
struct BlocklistEditorModelTests {
    @Test func addsNormalizedDomainsAndReportsProblems() {
        let model = BlocklistEditorModel(store: LockInStore(storage: InMemoryStorage()), onSave: {})
        model.domainInput = "https://www.Reddit.com/r/all"
        model.addDomain()
        #expect(model.blocklist.customDomains == ["www.reddit.com"])
        #expect(model.domainInput.isEmpty)
        #expect(model.domainError == nil)

        model.domainInput = "nope"
        model.addDomain()
        #expect(model.domainError == "That doesn't look like a website.")

        model.domainInput = "www.reddit.com"
        model.addDomain()
        #expect(model.domainError == "Already blocked.")
    }

    @Test func saveWritesTheStoreAndNotifies() throws {
        let store = LockInStore(storage: InMemoryStorage())
        var saved = 0
        let model = BlocklistEditorModel(store: store, onSave: { saved += 1 })
        model.blocklist = try Fixtures.blocklist(apps: 1, customDomains: ["x.com"])
        model.save()
        #expect(store.read(.blocklist) == model.blocklist)
        #expect(saved == 1)
    }

    @Test func removesDomains() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write(Blocklist(customDomains: ["a.com", "b.com"]), to: .blocklist)
        let model = BlocklistEditorModel(store: store, onSave: {})
        model.removeDomains(at: IndexSet(integer: 0))
        #expect(model.blocklist.customDomains == ["b.com"])
    }
}
