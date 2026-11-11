#if os(iOS)
import Foundation
import LockInCore

/// Reads current state, asks `ShieldDecision`, applies the answer. Holds no rules of its own.
/// The app calls it after every change; the DeviceActivityMonitor extension calls it on every interval.
public struct ShieldEnforcer {
    private let store: LockInStore
    private let applier: ShieldApplier
    private let calendar: Calendar

    public init(store: LockInStore, applier: ShieldApplier, calendar: Calendar = .current) {
        self.store = store
        self.applier = applier
        self.calendar = calendar
    }

    /// Returns whether the Shield is now up.
    @discardableResult
    public func reevaluate(now: Date = Date()) -> Bool {
        let shielded = ShieldDecision.shouldShield(
            at: now,
            tasks: store.read(.tasks),
            completions: store.read(.completions),
            calendar: calendar
        )
        applier.update(shielded: shielded, blocklist: store.read(.blocklist))
        return shielded
    }
}
#endif
