import Foundation

/// A calendar Day (see GLOSSARY). Every rule in LockIn is evaluated per Day.
public struct DayKey: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: year, month: month, day: day)
        guard let date = cal.date(from: comps),
              cal.dateComponents([.year, .month, .day], from: date) == comps else { return nil }
        (self.year, self.month, self.day) = (year, month, day)
    }

    /// Parses `yyyy-MM-dd`.
    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// The Day containing `date` in the calendar's time zone.
    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        (year, month, day) = (c.year!, c.month!, c.day!)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func weekday(in calendar: Calendar) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: startOfDay(in: calendar)))!
    }

    /// Midnight at the start of this Day in the calendar's time zone.
    public func startOfDay(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// The instant a `TimeOfDay` falls on this Day.
    public func instant(at time: TimeOfDay, in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: time.hour, minute: time.minute))!
    }

    public func adding(days: Int, in calendar: Calendar) -> DayKey {
        DayKey(calendar.date(byAdding: .day, value: days, to: startOfDay(in: calendar))!, calendar: calendar)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension DayKey: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid DayKey \(raw)"))
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}

/// `DayKey` is used as a dictionary key, so it must encode as a JSON object key, not an array.
extension DayKey: CodingKeyRepresentable {
    public var codingKey: CodingKey { StringKey(description) }
    public init?<T: CodingKey>(codingKey: T) { self.init(codingKey.stringValue) }
}

struct StringKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

public enum Weekday: Int, CaseIterable, Codable, Hashable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}
