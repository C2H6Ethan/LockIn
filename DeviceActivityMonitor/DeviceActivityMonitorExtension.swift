import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        let isDailySchedule = activity.rawValue == Constants.DeviceActivity.dailySchedule
        let isStartTimeSchedule = activity.rawValue.hasPrefix(Constants.DeviceActivity.startTimePrefix)
        guard isDailySchedule || isStartTimeSchedule else { return }

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
        let hasApps = !selection.applicationTokens.isEmpty
        let hasIncomplete = !store.incompleteBlockingTasks.isEmpty

        if hasIncomplete && hasApps {
            managedStore.shield.applications = selection.applicationTokens
        } else {
            managedStore.shield.applications = nil
        }
    }

}
