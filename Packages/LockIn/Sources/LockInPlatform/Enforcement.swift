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
    private let poster: NotificationPoster
    private let calendar: Calendar
    private let source: Event.Source

    public static let reminderNotificationID = "reminder"
    public static let todayURL = URL(string: "lockin://today")!

    public init(store: LockInStore, registrar: ScheduleRegistrar, enforcer: ShieldEnforcer, poster: NotificationPoster = UserNotificationPoster(), calendar: Calendar = .current, source: Event.Source) {
        self.store = store
        self.registrar = registrar
        self.enforcer = enforcer
        self.poster = poster
        self.calendar = calendar
        self.source = source
    }

    /// Production wiring over the App Group. `nil` only if the App Group entitlement is missing.
    public static func live(source: Event.Source) -> Enforcement? {
        guard let storage = UserDefaultsStorage.appGroup() else { return nil }
        let store = LockInStore.logging(storage: storage, source: source)
        // Whichever process runs first after the update imports v2, so the user needn't open the app.
        if let v2 = UserDefaults(suiteName: AppGroup.id) {
            V2Migration.runIfNeeded(store: store, v2: v2)
        }
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
        finalizeEndedDays(today: today, now: now)
        let desired = ScheduledActivity.desired(tasks: store.read(.tasks), reminderTime: store.read(.settings).reminderTime, today: today)
        let report = registrar.sync(desired: desired)
        if let summary = report.summary { store.log(summary, source: source, at: now) }
        let shielded = enforcer.reevaluate(now: now)
        store.log("\(reason): shield \(shielded ? "up" : "down")", source: source, at: now)
    }

    /// Called by the DeviceActivityMonitor extension when an activity's interval starts.
    public func intervalDidStart(activityName: String, now: Date = Date()) {
        refresh(reason: "intervalDidStart \(activityName)", now: now)
        if case .reminder = ScheduledActivity(name: activityName) { postReminderIfOwed(now: now) }
    }

    private func postReminderIfOwed(now: Date) {
        let content = Reminder.content(
            tasks: store.read(.tasks),
            completions: store.read(.completions),
            day: DayKey(now, calendar: calendar),
            calendar: calendar
        )
        guard let content else {
            store.log("Reminder skipped: nothing owed", source: source, at: now)
            return
        }
        poster.post(id: Self.reminderNotificationID, title: content.title, body: content.body, deepLink: Self.todayURL)
        store.log("Reminder posted: \(content.title)", source: source, at: now)
    }

    /// Writes a Day record for every Day that has ended (008). The first writer wins, so the extension's
    /// midnight run captures each Day as it really ended; the app fills any gaps.
    private func finalizeEndedDays(today: DayKey, now: Date) {
        let existing = store.read(.dayRecords)
        let updated = DayRecords.finalized(
            existing: existing,
            through: today.adding(days: -1, in: calendar),
            firstDay: store.read(.settings).firstDay,
            tasks: store.read(.tasks),
            completions: store.read(.completions),
            calendar: calendar
        )
        guard updated.count != existing.count else { return }
        store.write(updated, to: .dayRecords)
        let added = updated.keys.filter { existing[$0] == nil }.sorted()
        let outcomes = added.map { "\($0) \(updated[$0]!.outcome.rawValue)" }.joined(separator: ", ")
        store.log("Finalized \(outcomes)", source: source, at: now)
    }
}
#endif
