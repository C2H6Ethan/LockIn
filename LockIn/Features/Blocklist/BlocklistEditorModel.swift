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

    private let store: LockInStore
    private let onSave: () -> Void

    init(store: LockInStore, onSave: @escaping () -> Void) {
        self.store = store
        self.onSave = onSave
        self.blocklist = store.read(.blocklist)
    }

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
        for index in offsets.sorted(by: >) { blocklist.customDomains.remove(at: index) }
    }

    private static func count(_ n: Int, _ singular: String, _ plural: String) -> String? {
        n == 0 ? nil : "\(n) \(n == 1 ? singular : plural)"
    }

    func save() {
        store.write(blocklist, to: .blocklist)
        onSave()
    }
}
