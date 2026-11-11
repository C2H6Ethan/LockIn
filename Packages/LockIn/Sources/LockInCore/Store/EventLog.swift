import Foundation

/// A small ring buffer of what happened, written by the app and every extension.
/// It is the only way to see what the background did on a real device.
public struct EventLog: Hashable, Codable, Sendable {
    public static let capacity = 200
    public private(set) var events: [Event]

    public init(events: [Event] = []) {
        self.events = Array(events.suffix(Self.capacity))
    }

    public mutating func append(_ event: Event) {
        events.append(event)
        if events.count > Self.capacity { events.removeFirst(events.count - Self.capacity) }
    }
}

public struct Event: Hashable, Codable, Sendable {
    public enum Source: String, Codable, Sendable {
        case app, monitor, shieldAction, shieldConfiguration, widget
    }

    public let date: Date
    public let source: Source
    public let message: String

    public init(date: Date, source: Source, message: String) {
        self.date = date
        self.source = source
        self.message = message
    }
}

extension Document where Value == EventLog {
    public static let eventLog = Document("eventLog") { EventLog() }
}

extension LockInStore {
    /// A store that records corrupt documents in the event log.
    public static func logging(storage: any KeyValueStorage, source: Event.Source) -> LockInStore {
        LockInStore(
            storage: storage,
            onCorruptDocument: { key, error in
                LockInStore(storage: storage).log("Corrupt \(key): \(error)", source: source)
            },
            onWriteFailure: { key, error in
                LockInStore(storage: storage).log("Write failed \(key): \(error)", source: source)
            }
        )
    }

    public func log(_ message: String, source: Event.Source, at date: Date = Date()) {
        var log = read(.eventLog)
        log.append(Event(date: date, source: source, message: message))
        write(log, to: .eventLog)
    }
}
