import Foundation

/// A clock time in 15-minute steps, no later than 23:30 (see GLOSSARY: Start Time).
/// The cap keeps every DeviceActivity interval at least 29 minutes long; iOS rejects anything under 15.
public struct TimeOfDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    public static let step = 15
    public static let latest = TimeOfDay(minutesSinceMidnight: 23 * 60 + 30)!

    public let minutesSinceMidnight: Int

    public var hour: Int { minutesSinceMidnight / 60 }
    public var minute: Int { minutesSinceMidnight % 60 }

    public init?(minutesSinceMidnight: Int) {
        guard minutesSinceMidnight >= 0, minutesSinceMidnight <= 23 * 60 + 30,
              minutesSinceMidnight % Self.step == 0 else { return nil }
        self.minutesSinceMidnight = minutesSinceMidnight
    }

    public init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.init(minutesSinceMidnight: hour * 60 + minute)
    }

    /// Rounds an arbitrary clock time to the nearest allowed value and caps it at 23:30.
    public static func nearestAllowed(hour: Int, minute: Int) -> TimeOfDay {
        let total = hour * 60 + minute
        let rounded = Int((Double(total) / Double(step)).rounded()) * step
        return TimeOfDay(minutesSinceMidnight: min(rounded, latest.minutesSinceMidnight))!
    }

    public var description: String { String(format: "%02d:%02d", hour, minute) }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

extension TimeOfDay: Codable {
    public init(from decoder: Decoder) throws {
        let minutes = try decoder.singleValueContainer().decode(Int.self)
        guard let value = TimeOfDay(minutesSinceMidnight: minutes) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid TimeOfDay \(minutes)"))
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(minutesSinceMidnight)
    }
}
