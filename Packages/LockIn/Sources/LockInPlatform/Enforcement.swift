#if os(iOS)
import Foundation
import LockInCore

/// Brings the device in line with the stored state: schedules registered, Shield up or down, outcome logged.
/// The app runs it after every change and on launch; the DeviceActivityMonitor extension runs it on every interval,
/// so enforcement keeps working when the app is never opened (ADR 0001).
public struct Enforcement {
    private let store: LockInStore
    private let registrar: ScheduleRegistrar
    private let enforcer: ShieldEnforcer
    private let calendar: Calendar
    private let source: Event.Source

    public init(store: LockInStore, registrar: ScheduleRegistrar, enforcer: ShieldEnforcer, calendar: Calendar = .current, source: Event.Source) {
        self.store = store
        self.registrar = registrar
        self.enforcer = enforcer
        self.calendar = calendar
        self.source = source
    }

    /// Production wiring over the App Group. `nil` only if the App Group entitlement is missing.
    public static func live(source: Event.Source) -> Enforcement? {
        guard let storage = UserDefaultsStorage.appGroup() else { return nil }
        let store = LockInStore.logging(storage: storage, source: source)
        return Enforcement(
            store: store,
            registrar: ScheduleRegistrar(),
            enforcer: ShieldEnforcer(store: store, applier: .live()),
            source: source
        )
    }

    public var storeForReading: LockInStore { store }

    /// `reason` is recorded in the event log, e.g. "launch" or "intervalDidStart day".
    public func refresh(reason: String, now: Date = Date()) {
        let today = DayKey(now, calendar: calendar)
        let report = registrar.sync(desired: ScheduledActivity.desired(tasks: store.read(.tasks), today: today))
        if let summary = report.summary { store.log(summary, source: source, at: now) }
        let shielded = enforcer.reevaluate(now: now)
        store.log("\(reason): shield \(shielded ? "up" : "down")", source: source, at: now)
    }
}
#endif
