import DeviceActivity
import LockInCore
import LockInPlatform

/// Runs LockIn's daily enforcement while the app is closed (ADR 0001). No rules live here.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        Enforcement.live(source: .monitor)?.intervalDidStart(activityName: activity.rawValue)
    }
}
