import Foundation
import Testing
@testable import LockInCore

struct StoreTests {
    static func storages() -> [any KeyValueStorage] {
        let suite = "test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return [InMemoryStorage(), UserDefaultsStorage(defaults: defaults)]
    }

    @Test(arguments: storages())
    func tasksRoundTrip(storage: any KeyValueStorage) {
        let store = LockInStore(storage: storage)
        let tasks = [task("Read", startTime: time(9)), task("Gym", schedule: .once(day("2026-11-12")), requirement: .optional)]
        store.write(tasks, to: .tasks)
        #expect(store.read(.tasks) == tasks)
    }

    @Test(arguments: storages())
    func completionsAndSettingsRoundTrip(storage: any KeyValueStorage) {
        let store = LockInStore(storage: storage)
        var log = CompletionLog()
        log.set(UUID(), completed: true, on: day("2026-11-10"))
        store.write(log, to: .completions)
        var settings = Settings()
        settings.reminderTime = time(21)
        settings.firstDay = day("2026-11-01")
        settings.hasCompletedOnboarding = true
        store.write(settings, to: .settings)
        #expect(store.read(.completions) == log)
        #expect(store.read(.settings) == settings)
    }

    @Test func missingDocumentsReadAsDefaults() {
        let store = LockInStore(storage: InMemoryStorage())
        #expect(store.read(.tasks).isEmpty)
        #expect(store.read(.completions) == CompletionLog())
        #expect(store.read(.settings) == Settings())
        #expect(store.read(.schemaVersion) == nil)
    }

    @Test func corruptDocumentReadsAsDefaultAndReportsTheFailure() {
        let storage = InMemoryStorage()
        storage.set(Data("not json".utf8), forKey: Document.tasks.key)
        let reported = Reported()
        let store = LockInStore(storage: storage, onCorruptDocument: { key, _ in reported.append(key) })
        #expect(store.read(.tasks).isEmpty)
        #expect(reported.keys == ["v3.tasks"])
    }

    @Test func keysArePrefixedForV3() {
        #expect(Document.tasks.key == "v3.tasks")
        #expect(Document.completions.key == "v3.completions")
        #expect(Document.settings.key == "v3.settings")
        #expect(Document.schemaVersion.key == "v3.schemaVersion")
    }

    @Test func savingCompletionsPrunesToTheLast120Days() {
        let store = LockInStore(storage: InMemoryStorage())
        let id = UUID()
        var log = CompletionLog()
        let today = day("2026-11-10")
        for offset in 0...200 {
            log.set(id, completed: true, on: today.adding(days: -offset, in: calendar()))
        }
        store.saveCompletions(log, today: today, calendar: calendar())
        let saved = store.read(.completions)
        #expect(saved.completed.count == 120)
        #expect(saved.isCompleted(id, on: today))
        #expect(saved.isCompleted(id, on: today.adding(days: -119, in: calendar())))
        #expect(!saved.isCompleted(id, on: today.adding(days: -120, in: calendar())))
    }

    @Test func settingsDecodeWithMissingFieldsForForwardCompatibility() throws {
        let decoded = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        #expect(decoded == Settings())
        #expect(decoded.reminderTime == time(20))
    }

    @Test func userDefaultsStorageSynchronizesAfterEveryWrite() {
        let defaults = SpyDefaults(suiteName: "test.spy.\(UUID().uuidString)")!
        let storage = UserDefaultsStorage(defaults: defaults)
        storage.set(Data([1]), forKey: "a")
        storage.set(nil, forKey: "a")
        #expect(defaults.synchronizeCount == 2)
        #expect(storage.data(forKey: "a") == nil)
    }
}

private final class Reported: @unchecked Sendable {
    private let lock = NSLock()
    private var _keys: [String] = []
    var keys: [String] { lock.withLock { _keys } }
    func append(_ key: String) { lock.withLock { _keys.append(key) } }
}

private final class SpyDefaults: UserDefaults, @unchecked Sendable {
    var synchronizeCount = 0
    override func synchronize() -> Bool {
        synchronizeCount += 1
        return super.synchronize()
    }
}
