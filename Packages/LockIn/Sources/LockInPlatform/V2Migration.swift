#if os(iOS)
import FamilyControls
import Foundation
import LockInCore

/// One-time import of v2 data, which lives under unprefixed keys in the same App Group (ticket 014).
public enum V2Migration {
    public static let currentSchemaVersion = 3

    public enum Outcome: Equatable, Sendable {
        case notNeeded, imported, failed
    }

    /// Imports v2 data unless this store has already been claimed by v3. Never throws, never retries.
    /// v2 keys are left untouched.
    @discardableResult
    public static func runIfNeeded(store: LockInStore, v2: UserDefaults, now: Date = Date(), calendar: Calendar = .current) -> Outcome {
        guard store.read(.schemaVersion) == nil else { return .notNeeded }
        defer { store.write(currentSchemaVersion, to: .schemaVersion) }

        let snapshot = V2Snapshot(
            tasks: v2.data(forKey: "tasks"),
            completionLog: v2.data(forKey: "completionLog"),
            streakData: v2.data(forKey: "streakData"),
            selectedWebDomains: v2.stringArray(forKey: "selectedWebDomains"),
            reminderNever: v2.bool(forKey: "reminderNever"),
            reminderHour: v2.object(forKey: "reminderHour") as? Int,
            reminderMinute: v2.object(forKey: "reminderMinute") as? Int,
            hasCompletedOnboarding: v2.bool(forKey: "hasCompletedOnboarding")
        )
        guard snapshot.isPresent else { return .notNeeded }

        let result: V2ImportResult
        do {
            result = try V2Import.map(snapshot, today: DayKey(now, calendar: calendar), calendar: calendar)
        } catch {
            store.log("v2 import failed: \(error)", source: .app)
            return .failed
        }

        var selection = FamilyActivitySelection()
        if let data = v2.data(forKey: "selectedApps") {
            do {
                selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            } catch {
                // Tasks matter more than the Blocklist; the user can re-pick apps.
                store.log("v2 import: Blocklist apps unreadable: \(error)", source: .app)
            }
        }

        store.write(result.tasks, to: .tasks)
        store.write(result.completions, to: .completions)
        store.write(result.settings, to: .settings)
        store.write(Blocklist(selection: selection, customDomains: result.customDomains), to: .blocklist)
        store.write(result.leftovers, to: .v2Leftovers)
        store.log("v2 import: \(result.tasks.count) tasks, streak seed \(result.settings.streakSeed?.count ?? 0)", source: .app)
        return .imported
    }
}
#endif
