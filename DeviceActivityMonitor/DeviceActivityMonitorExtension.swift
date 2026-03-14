import DeviceActivity
import FamilyControls
import ManagedSettings

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue == Constants.DeviceActivity.weeklySchedule else { return }

        let store = SharedStore(suiteName: Constants.AppGroup.id)

        // Apply or remove shields directly (BlockingService is main-app only)
        let managedStore = ManagedSettingsStore()
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
