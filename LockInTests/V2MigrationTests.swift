import FamilyControls
import Foundation
import LockInCore
import LockInPlatform
import Testing

struct V2MigrationTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }
    let taskID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func v2Defaults(tasks: String? = nil) throws -> UserDefaults {
        let defaults = UserDefaults(suiteName: "v2-\(UUID())")!
        let json = tasks ?? #"[{"id":"\#(taskID)","title":"Read","recurrence":{"weekly":{"days":[1,2,3,4,5,6,7]}},"blocksApps":true,"createdAt":784000000}]"#
        defaults.set(Data(json.utf8), forKey: "tasks")
        defaults.set(Data(#"{"currentStreak":4,"longestStreak":4,"lastCompletedDate":"2026-11-09"}"#.utf8), forKey: "streakData")
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set(["youtube.com"], forKey: "selectedWebDomains")
        defaults.set(19, forKey: "reminderHour")
        defaults.set(30, forKey: "reminderMinute")
        defaults.set(try JSONEncoder().encode(Fixtures.blocklist(apps: 2, categories: 1).selection), forKey: "selectedApps")
        return defaults
    }

    @Test func importsEverythingAndMarksTheSchema() throws {
        let store = LockInStore(storage: InMemoryStorage())
        let outcome = V2Migration.runIfNeeded(store: store, v2: try v2Defaults(), now: now, calendar: cal)

        #expect(outcome == .imported)
        #expect(store.read(.tasks).map(\.title) == ["Read"])
        #expect(store.read(.settings).hasCompletedOnboarding)
        #expect(store.read(.settings).reminderTime == TimeOfDay(hour: 19, minute: 30))
        #expect(store.read(.settings).streakSeed == StreakSeed(count: 4, asOf: DayKey("2026-11-09")!))
        #expect(store.read(.blocklist).appCount == 2)
        #expect(store.read(.blocklist).categoryCount == 1)
        #expect(store.read(.blocklist).customDomains == ["youtube.com"])
        #expect(store.read(.schemaVersion) == V2Migration.currentSchemaVersion)
    }

    @Test func runsOnlyOnce() throws {
        let store = LockInStore(storage: InMemoryStorage())
        let v2 = try v2Defaults()
        _ = V2Migration.runIfNeeded(store: store, v2: v2, now: now, calendar: cal)
        store.write([], to: .tasks)  // the user deletes everything in v3
        #expect(V2Migration.runIfNeeded(store: store, v2: v2, now: now, calendar: cal) == .notNeeded)
        #expect(store.read(.tasks).isEmpty)
    }

    @Test func corruptTasksSkipTheImportAndLeaveOnboarding() throws {
        let store = LockInStore(storage: InMemoryStorage())
        let outcome = V2Migration.runIfNeeded(store: store, v2: try v2Defaults(tasks: "{not json"), now: now, calendar: cal)

        #expect(outcome == .failed)
        #expect(store.read(.tasks).isEmpty)
        #expect(!store.read(.settings).hasCompletedOnboarding)
        #expect(store.read(.schemaVersion) == V2Migration.currentSchemaVersion)  // never retried
        #expect(store.read(.eventLog).events.contains { $0.message.contains("v2 import failed") })
    }

    @Test func freshInstallNeedsNothing() {
        let store = LockInStore(storage: InMemoryStorage())
        let empty = UserDefaults(suiteName: "v2-\(UUID())")!
        #expect(V2Migration.runIfNeeded(store: store, v2: empty, now: now, calendar: cal) == .notNeeded)
        #expect(store.read(.schemaVersion) == V2Migration.currentSchemaVersion)
    }

    @Test func unreadableSelectionStillImportsTasks() throws {
        let store = LockInStore(storage: InMemoryStorage())
        let v2 = try v2Defaults()
        v2.set(Data("junk".utf8), forKey: "selectedApps")
        #expect(V2Migration.runIfNeeded(store: store, v2: v2, now: now, calendar: cal) == .imported)
        #expect(store.read(.tasks).count == 1)
        #expect(store.read(.blocklist).appCount == 0)
        #expect(store.read(.blocklist).customDomains == ["youtube.com"])
    }
}
