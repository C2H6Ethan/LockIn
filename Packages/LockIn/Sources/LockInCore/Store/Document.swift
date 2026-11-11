import Foundation

/// A named, JSON-encoded value in storage. Keys carry the `v3.` prefix so they never collide with v2 data.
public struct Document<Value: Codable & Sendable>: Sendable {
    public let key: String
    public let defaultValue: @Sendable () -> Value

    public init(_ name: String, default defaultValue: @escaping @Sendable () -> Value) {
        self.key = "v3." + name
        self.defaultValue = defaultValue
    }
}

extension Document where Value == [LockInTask] {
    public static let tasks = Document("tasks") { [] }
}

extension Document where Value == CompletionLog {
    public static let completions = Document("completions") { CompletionLog() }
}

extension Document where Value == Settings {
    public static let settings = Document("settings") { Settings() }
}

extension Document where Value == Int? {
    /// Absent until the first v3 write or a successful v2 import.
    public static let schemaVersion = Document("schemaVersion") { nil }
}
