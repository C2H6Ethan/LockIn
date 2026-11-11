import Foundation
import LockInCore
import Observation

@MainActor
@Observable
final class SettingsModel {
    private(set) var settings: Settings

    private let store: LockInStore
    private let calendar: Calendar
    private let now: () -> Date
    private let onChange: () -> Void

    init(store: LockInStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init, onChange: @escaping () -> Void) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.onChange = onChange
        self.settings = store.read(.settings)
        reload()
    }

    func reload() {
        settings = store.read(.settings)
    }

    /// When Lock Mode ends, if it's on.
    var lockedUntil: Date? {
        let mode = store.read(.lockMode)
        return mode.isActive(at: now()) ? mode.lockedUntil : nil
    }

    /// When Lock Mode would end if started (or extended) now for `days`. Same rule `lock(days:)` saves.
    func lockedUntil(ifLockedFor days: Int) -> Date {
        var mode = store.read(.lockMode)
        mode.lock(days: days, now: now())
        return mode.lockedUntil ?? now()
    }

    /// Starts or extends Lock Mode. There is no way to end it early.
    func lock(days: Int) {
        var mode = store.read(.lockMode)
        mode.lock(days: days, now: now())
        store.write(mode, to: .lockMode)
        reload()
    }

    var reminderTime: TimeOfDay? {
        get { settings.reminderTime }
        set {
            settings.reminderTime = newValue
            store.write(settings, to: .settings)
            onChange()
        }
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }
}
