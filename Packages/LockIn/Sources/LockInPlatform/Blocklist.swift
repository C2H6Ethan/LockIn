#if os(iOS)
import FamilyControls
import LockInCore

/// The apps, categories and websites to shield (see GLOSSARY: Blocklist).
public struct Blocklist: Codable, Equatable, Sendable {
    public var selection: FamilyActivitySelection
    /// Normalized via `CustomDomain`.
    public var customDomains: [String]

    public init(selection: FamilyActivitySelection = FamilyActivitySelection(), customDomains: [String] = []) {
        self.selection = selection
        self.customDomains = customDomains
    }

    public var appCount: Int { selection.applicationTokens.count }
    public var categoryCount: Int { selection.categoryTokens.count }
    public var webDomainCount: Int { selection.webDomainTokens.count }

    public var isEmpty: Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
            && customDomains.isEmpty
    }
}

extension FamilyActivitySelection: @retroactive @unchecked Sendable {}

extension Document where Value == Blocklist {
    public static let blocklist = Document("blocklist") { Blocklist() }
}
#endif
