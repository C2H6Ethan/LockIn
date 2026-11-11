import Foundation

/// Raw bytes keyed by string. The only thing persistence needs from the platform.
public protocol KeyValueStorage: Sendable {
    func data(forKey key: String) -> Data?
    /// `nil` removes the key.
    func set(_ data: Data?, forKey key: String)
}

/// Storage for tests and previews.
public final class InMemoryStorage: KeyValueStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? {
        lock.withLock { values[key] }
    }

    public func set(_ data: Data?, forKey key: String) {
        lock.withLock { values[key] = data }
    }
}

/// `UserDefaults`-backed storage. Use the App Group suite so every target sees the same data.
/// Synchronizes after every write because extensions read immediately after the app writes.
public struct UserDefaultsStorage: KeyValueStorage {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The shared App Group suite. Returns `nil` only if the entitlement is missing.
    public static func appGroup() -> UserDefaultsStorage? {
        UserDefaults(suiteName: AppGroup.id).map(UserDefaultsStorage.init)
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func set(_ data: Data?, forKey key: String) {
        if let data { defaults.set(data, forKey: key) } else { defaults.removeObject(forKey: key) }
        defaults.synchronize()
    }
}

extension UserDefaults: @retroactive @unchecked Sendable {}
