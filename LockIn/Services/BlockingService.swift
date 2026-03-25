import Foundation
import FamilyControls
import ManagedSettings
import UserNotifications

// MARK: - Protocol (enables test injection)

protocol ShieldApplying {
    func apply(selection: FamilyActivitySelection)
    func remove()
}

// MARK: - Live Applier

final class ManagedSettingsShieldApplier: ShieldApplying {
    private lazy var managedStore = ManagedSettingsStore()

    func apply(selection: FamilyActivitySelection) {
        let tokens = selection.applicationTokens
        managedStore.shield.applications = tokens.isEmpty ? nil : tokens
    }

    func remove() {
        managedStore.shield.applications = nil
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

        // Clean up expired bypass
        store.unblockExpiresAt = nil

        let blocking = store.incompleteBlockingTasks
        let selection = store.selectedApps
        let hasApps = !selection.applicationTokens.isEmpty

        if !blocking.isEmpty && hasApps {
            applier.apply(selection: selection)
        } else {
            applier.remove()
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
