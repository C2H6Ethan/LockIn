import Foundation
import LockInCore
import LockInPlatform
import Observation

@MainActor
@Observable
final class BlocklistEditorModel {
    var blocklist: Blocklist
    var domainInput = ""
    private(set) var domainError: String?
    /// Why a removal or Save was refused in Lock Mode.
    private(set) var lockMessage: String?

    private let store: LockInStore
    private let now: () -> Date
    private let onSave: () -> Void
    private let saved: Blocklist

    static let lockedText = "Lock Mode is on: you can add to the Blocklist, not remove from it."

    init(store: LockInStore, now: @escaping () -> Date = Date.init, onSave: @escaping () -> Void) {
        self.store = store
        self.now = now
        self.onSave = onSave
        self.saved = store.read(.blocklist)
        self.blocklist = saved
    }

    var isLocked: Bool { store.read(.lockMode).isActive(at: now()) }

    var pickedSummary: String {
        let parts = [
            Self.count(blocklist.appCount, "app", "apps"),
            Self.count(blocklist.categoryCount, "category", "categories"),
            Self.count(blocklist.webDomainCount, "website", "websites"),
        ].compactMap { $0 }
        return parts.isEmpty ? "Nothing picked yet" : parts.joined(separator: ", ")
    }

    func addDomain() {
        switch CustomDomain.add(domainInput, to: &blocklist.customDomains) {
        case .added:
            domainInput = ""
            domainError = nil
        case .duplicate:
            domainError = "Already blocked."
        case .invalid:
            domainError = "That doesn't look like a website."
        case .limitReached:
            domainError = "You can block up to \(CustomDomain.limit) websites."
        }
    }

    func removeDomains(at offsets: IndexSet) {
        guard !isLocked else {
            lockMessage = Self.lockedText
            return
        }
        for index in offsets.sorted(by: >) { blocklist.customDomains.remove(at: index) }
    }

    private static func count(_ n: Int, _ singular: String, _ plural: String) -> String? {
        n == 0 ? nil : "\(n) \(n == 1 ? singular : plural)"
    }

    /// Returns whether it was saved. In Lock Mode, anything that removes an item is refused.
    @discardableResult
    func save() -> Bool {
        if isLocked, !LockPolicy.allows(from: saved, to: blocklist) {
            lockMessage = Self.lockedText
            return false
        }
        store.write(blocklist, to: .blocklist)
        onSave()
        return true
    }
}
