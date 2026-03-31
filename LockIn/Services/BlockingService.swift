import Foundation
import FamilyControls
import ManagedSettings
import UserNotifications

// MARK: - Protocol (enables test injection)

protocol ShieldApplying {
    func apply(selection: FamilyActivitySelection, customDomains: [String])
    func remove()
}

// MARK: - Live Applier

final class ManagedSettingsShieldApplier: ShieldApplying {
    private lazy var managedStore = ManagedSettingsStore()

    func apply(selection: FamilyActivitySelection, customDomains: [String]) {
        let appTokens = selection.applicationTokens
        managedStore.shield.applications = appTokens.isEmpty ? nil : appTokens
        let categoryTokens = selection.categoryTokens
        managedStore.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        managedStore.shield.webDomainCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)
        let webTokens = selection.webDomainTokens
        managedStore.shield.webDomains = webTokens.isEmpty ? nil : webTokens
        if customDomains.isEmpty {
            managedStore.webContent.blockedByFilter = nil
        } else {
            managedStore.webContent.blockedByFilter = .specific(Set(customDomains.map { WebDomain(domain: $0) }))
        }
    }

    func remove() {
        managedStore.shield.applications = nil
        managedStore.shield.applicationCategories = nil
        managedStore.shield.webDomains = nil
        managedStore.shield.webDomainCategories = nil
        managedStore.webContent.blockedByFilter = nil
    }
}

// MARK: - BlockingService

final class BlockingService {

    static let shared = BlockingService()

    private let store: SharedStore
    private let applier: any ShieldApplying

    init(store: SharedStore = .shared, applier: any ShieldApplying = ManagedSettingsShieldApplier()) {
        self.store = store
        self.applier = applier
    }

    // MARK: - Public API

    /// Apply or remove shields based on current habit completion + app selection state.
    /// If a bypass window is active, shields stay removed until it expires.
    func updateShieldsForCurrentHabitState() {
        // Bypass still active — keep shields removed
        if let expires = store.unblockExpiresAt, expires > Date() { return }

        // Clean up expired bypass + cancel the pending notification
        store.unblockExpiresAt = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bypass-expiry"])

        let blocking = store.incompleteBlockingTasks
        let selection = store.selectedApps
        let customDomains = store.selectedWebDomains
        let hasApps = !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
        let hasDomains = !selection.webDomainTokens.isEmpty
        let hasCustomDomains = !customDomains.isEmpty

        if !blocking.isEmpty && (hasApps || hasDomains || hasCustomDomains) {
            applier.apply(selection: selection, customDomains: customDomains)
        } else {
            applier.remove()
            // No blocking needed — clean up any pending bypass notification/flag
            if store.bypassRequested {
                store.bypassRequested = false
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [Constants.Stepping.notificationID])
                center.removeDeliveredNotifications(withIdentifiers: [Constants.Stepping.notificationID])
            }
        }
    }

    /// Start a bypass window: removes shields so the user can use blocked apps.
    /// Re-blocking happens via:
    /// 1. DeviceActivityMonitor `intervalDidStart` at expiry (out-of-process, reliable)
    /// 2. App foreground check (`scenePhase → .active → updateShields`)
    /// 3. "Break's over" notification tap opens app → re-applies shields
    func temporaryUnblock(duration: TimeInterval = Constants.Bypass.defaultWindowDuration) {
        store.unblockExpiresAt = Date().addingTimeInterval(duration)
        applier.remove()

        // Schedule out-of-process re-block via DeviceActivityMonitor
        SchedulingService.shared.scheduleBypassExpiry(duration: duration)

        // Notification reminder when break ends — tapping opens app → re-applies shields
        let content = UNMutableNotificationContent()
        content.title = "Break's over"
        content.body = "Your apps are blocked again. Time to lock in."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let request = UNNotificationRequest(identifier: "bypass-expiry", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
