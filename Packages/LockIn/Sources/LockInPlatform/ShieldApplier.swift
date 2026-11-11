#if os(iOS)
import Foundation
import ManagedSettings

/// The ManagedSettings fields LockIn writes. Exists so the mapping can be tested with a fake.
public protocol ShieldTarget: AnyObject {
    var applications: Set<ApplicationToken>? { get set }
    var applicationCategories: ShieldSettings.ActivityCategoryPolicy<Application>? { get set }
    var webDomains: Set<WebDomainToken>? { get set }
    var webDomainCategories: ShieldSettings.ActivityCategoryPolicy<WebDomain>? { get set }
    var blockedByFilter: WebContentSettings.FilterPolicy? { get set }
    func clearAll()
    /// Empties stores written by older versions (v2 used the default store), so their shields can't linger.
    func clearLegacyStores()
}

/// The only code in LockIn that touches ManagedSettings. The app and every extension use it.
public struct ShieldApplier {
    private let target: ShieldTarget

    public init(target: ShieldTarget) {
        self.target = target
    }

    /// The production applier, backed by LockIn's named ManagedSettings store.
    public static func live() -> ShieldApplier {
        ShieldApplier(target: ManagedSettingsShieldTarget())
    }

    /// Shields every part of the Blocklist, replacing whatever was shielded before.
    public func apply(_ blocklist: Blocklist) {
        let selection = blocklist.selection
        let categories = selection.categoryTokens
        target.applications = selection.applicationTokens.nilIfEmpty
        target.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        target.webDomains = selection.webDomainTokens.nilIfEmpty
        target.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        target.blockedByFilter = blocklist.customDomains.isEmpty
            ? nil
            : .specific(Set(blocklist.customDomains.map { WebDomain(domain: $0) }))
    }

    public func clear() {
        target.clearAll()
    }

    /// Applies or clears in one call, the shape every caller needs after asking `ShieldDecision`.
    public func update(shielded: Bool, blocklist: Blocklist) {
        target.clearLegacyStores()
        if shielded { apply(blocklist) } else { clear() }
    }
}

/// `ShieldTarget` over the named store `lockin.shield`.
public final class ManagedSettingsShieldTarget: ShieldTarget {
    public static let storeName = "lockin.shield"
    private let store = ManagedSettingsStore(named: .init(ManagedSettingsShieldTarget.storeName))

    public init() {}

    public var applications: Set<ApplicationToken>? {
        get { store.shield.applications }
        set { store.shield.applications = newValue }
    }

    public var applicationCategories: ShieldSettings.ActivityCategoryPolicy<Application>? {
        get { store.shield.applicationCategories }
        set { store.shield.applicationCategories = newValue }
    }

    public var webDomains: Set<WebDomainToken>? {
        get { store.shield.webDomains }
        set { store.shield.webDomains = newValue }
    }

    public var webDomainCategories: ShieldSettings.ActivityCategoryPolicy<WebDomain>? {
        get { store.shield.webDomainCategories }
        set { store.shield.webDomainCategories = newValue }
    }

    public var blockedByFilter: WebContentSettings.FilterPolicy? {
        get { store.webContent.blockedByFilter }
        set { store.webContent.blockedByFilter = newValue }
    }

    public func clearAll() {
        store.clearAllSettings()
    }

    public func clearLegacyStores() {
        ManagedSettingsStore().clearAllSettings()
    }
}

private extension Set {
    var nilIfEmpty: Set? { isEmpty ? nil : self }
}
#endif
