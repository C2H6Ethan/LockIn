import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        if activity.rawValue == Constants.DeviceActivity.bypassExpiry {
            let store = SharedStore(suiteName: Constants.AppGroup.id)
            store.unblockExpiresAt = nil
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bypass-expiry"])
            applyOrRemoveShields()
            return
        }

        let isDailySchedule = activity.rawValue == Constants.DeviceActivity.dailySchedule
        let isStartTimeSchedule = activity.rawValue.hasPrefix(Constants.DeviceActivity.startTimePrefix)
        guard isDailySchedule || isStartTimeSchedule else { return }

        applyOrRemoveShields()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Fallback in case intervalDidStart didn't fire for bypass expiry.
        guard activity.rawValue == Constants.DeviceActivity.bypassExpiry else { return }
        let store = SharedStore(suiteName: Constants.AppGroup.id)
        store.unblockExpiresAt = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bypass-expiry"])
        applyOrRemoveShields()
    }

    /// Reads current habit state from the App Group and applies/removes shields.
    /// Called at midnight (daily interval start) so shields reflect the new day's tasks.
    private func applyOrRemoveShields() {
        let store = SharedStore(suiteName: Constants.AppGroup.id)
        let managedStore = ManagedSettingsStore()

        // Respect temporary unblock window
        if let expires = store.unblockExpiresAt, expires > Date() { return }

        let selection = store.selectedApps
        let customDomains = store.selectedWebDomains
        let hasApps = !selection.applicationTokens.isEmpty
        let hasDomains = !selection.webDomainTokens.isEmpty
        let hasCustomDomains = !customDomains.isEmpty
        let hasIncomplete = !store.incompleteBlockingTasks.isEmpty

        if hasIncomplete && (hasApps || hasDomains || hasCustomDomains) {
            let appTokens = selection.applicationTokens
            managedStore.shield.applications = appTokens.isEmpty ? nil : appTokens
            let webTokens = selection.webDomainTokens
            managedStore.shield.webDomains = webTokens.isEmpty ? nil : webTokens
            if customDomains.isEmpty {
                managedStore.webContent.blockedByFilter = nil
            } else {
                managedStore.webContent.blockedByFilter = .specific(Set(customDomains.map { WebDomain(domain: $0) }))
            }
        } else {
            managedStore.shield.applications = nil
            managedStore.shield.webDomains = nil
            managedStore.webContent.blockedByFilter = nil
        }
    }

}
