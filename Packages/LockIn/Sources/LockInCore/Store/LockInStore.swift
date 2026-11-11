import Foundation

/// Typed access to every persisted document. Reads are pure; writes are explicit.
/// Decode only what you need: extensions have a tight memory budget.
public struct LockInStore: Sendable {
    public static let currentSchemaVersion = 1
    /// How many Days of completions to keep.
    public static let completionRetentionDays = 120

    private let storage: any KeyValueStorage
    private let onCorruptDocument: @Sendable (String, Error) -> Void
    private let onWriteFailure: @Sendable (String, Error) -> Void

    public init(
        storage: any KeyValueStorage,
        onCorruptDocument: @escaping @Sendable (String, Error) -> Void = { _, _ in },
        onWriteFailure: @escaping @Sendable (String, Error) -> Void = { _, _ in }
    ) {
        self.storage = storage
        self.onCorruptDocument = onCorruptDocument
        self.onWriteFailure = onWriteFailure
    }

    /// The stored value, or the document's default when absent or unreadable. Never throws, never crashes.
    public func read<V>(_ document: Document<V>) -> V {
        guard let data = storage.data(forKey: document.key) else { return document.defaultValue() }
        do {
            return try JSONDecoder().decode(V.self, from: data)
        } catch {
            onCorruptDocument(document.key, error)
            return document.defaultValue()
        }
    }

    /// Never crashes: a value that can't be encoded (e.g. a NaN coordinate) is reported and the stored
    /// value is left unchanged. A crash here could take down the DeviceActivityMonitor extension.
    public func write<V>(_ value: V, to document: Document<V>) {
        do {
            storage.set(try JSONEncoder().encode(value), forKey: document.key)
        } catch {
            onWriteFailure(document.key, error)
        }
    }

    /// Writes completions pruned to the last `completionRetentionDays` Days.
    public func saveCompletions(_ log: CompletionLog, today: DayKey, calendar: Calendar) {
        let first = today.adding(days: -(Self.completionRetentionDays - 1), in: calendar)
        write(log.pruned(keepingFrom: first), to: .completions)
    }
}
