import FamilyControls
import Foundation
import LockInCore
import LockInPlatform
import ManagedSettings
import Testing

/// Regression guard for v2's bug: its background code ignored categories, so a category-only
/// Blocklist was never shielded at midnight. One applier, every field mapped, tested here.
@MainActor
struct ShieldApplierTests {
    @Test func applyMapsEveryBlocklistField() throws {
        let target = FakeShieldTarget()
        let blocklist = try Fixtures.blocklist(apps: 2, categories: 1, webDomains: 1, customDomains: ["reddit.com"])
        ShieldApplier(target: target).apply(blocklist)

        #expect(target.applications == blocklist.selection.applicationTokens)
        #expect(target.applicationCategories == .specific(blocklist.selection.categoryTokens))
        #expect(target.webDomainCategories == .specific(blocklist.selection.categoryTokens))
        #expect(target.webDomains == blocklist.selection.webDomainTokens)
        #expect(target.blockedByFilter == .specific([WebDomain(domain: "reddit.com")]))
    }

    @Test func categoryOnlyBlocklistIsShielded() throws {
        let target = FakeShieldTarget()
        ShieldApplier(target: target).apply(try Fixtures.blocklist(categories: 1))
        #expect(target.applicationCategories != nil)
        #expect(target.webDomainCategories != nil)
    }

    @Test func emptyFieldsAreLeftUnset() throws {
        let target = FakeShieldTarget()
        ShieldApplier(target: target).apply(try Fixtures.blocklist(apps: 1))
        #expect(target.applications?.count == 1)
        #expect(target.applicationCategories == nil)
        #expect(target.webDomainCategories == nil)
        #expect(target.webDomains == nil)
        #expect(target.blockedByFilter == nil)
    }

    @Test func applyReplacesThePreviousShieldCompletely() throws {
        let target = FakeShieldTarget()
        let applier = ShieldApplier(target: target)
        applier.apply(try Fixtures.blocklist(apps: 1, categories: 1, customDomains: ["x.com"]))
        applier.apply(try Fixtures.blocklist(webDomains: 1))
        #expect(target.applications == nil)
        #expect(target.applicationCategories == nil)
        #expect(target.blockedByFilter == nil)
        #expect(target.webDomains?.count == 1)
    }

    @Test func clearResetsEverything() throws {
        let target = FakeShieldTarget()
        let applier = ShieldApplier(target: target)
        applier.apply(try Fixtures.blocklist(apps: 1, categories: 1, webDomains: 1, customDomains: ["x.com"]))
        applier.clear()
        #expect(target.clearCount == 1)
        #expect(target.applications == nil)
        #expect(target.applicationCategories == nil)
        #expect(target.webDomainCategories == nil)
        #expect(target.webDomains == nil)
        #expect(target.blockedByFilter == nil)
    }

    @Test func blocklistRoundTripsThroughTheStore() throws {
        let store = LockInStore(storage: InMemoryStorage())
        let blocklist = try Fixtures.blocklist(apps: 1, categories: 1, webDomains: 1, customDomains: ["reddit.com"])
        store.write(blocklist, to: .blocklist)
        #expect(store.read(.blocklist) == blocklist)
        #expect(!blocklist.isEmpty)
        #expect(Blocklist().isEmpty)
    }
}

final class FakeShieldTarget: ShieldTarget {
    var applications: Set<ApplicationToken>?
    var applicationCategories: ShieldSettings.ActivityCategoryPolicy<Application>?
    var webDomains: Set<WebDomainToken>?
    var webDomainCategories: ShieldSettings.ActivityCategoryPolicy<WebDomain>?
    var blockedByFilter: WebContentSettings.FilterPolicy?
    var clearCount = 0

    func clearAll() {
        clearCount += 1
        applications = nil
        applicationCategories = nil
        webDomains = nil
        webDomainCategories = nil
        blockedByFilter = nil
    }
}

enum Fixtures {
    /// Screen Time tokens are opaque, but decode from any base64 payload, which is enough for tests.
    static func token<T: Decodable>(_ seed: Int) throws -> T {
        let payload = Data((0..<16).map { UInt8(($0 + seed) % 256) }).base64EncodedString()
        return try JSONDecoder().decode(T.self, from: Data(#"{"data":"\#(payload)"}"#.utf8))
    }

    static func blocklist(apps: Int = 0, categories: Int = 0, webDomains: Int = 0, customDomains: [String] = []) throws -> Blocklist {
        var selection = FamilyActivitySelection()
        selection.applicationTokens = Set(try (0..<apps).map { try token($0) })
        selection.categoryTokens = Set(try (0..<categories).map { try token(100 + $0) })
        selection.webDomainTokens = Set(try (0..<webDomains).map { try token(200 + $0) })
        return Blocklist(selection: selection, customDomains: customDomains)
    }
}
