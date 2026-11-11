import Foundation

/// A repeating background activity LockIn needs registered with DeviceActivity.
/// Each runs from `intervalStart` to the end of the Day, every day.
public enum ScheduledActivity: Hashable, Sendable {
    /// Fires at midnight: finalises yesterday and re-evaluates the Shield.
    case day
    /// Fires at a Start Time shared by one or more Required Tasks.
    case start(TimeOfDay)

    public static let dayName = "day"
    static let startPrefix = "start-"

    public var name: String {
        switch self {
        case .day: return Self.dayName
        case .start(let t): return Self.startPrefix + String(format: "%02d%02d", t.hour, t.minute)
        }
    }

    public init?(name: String) {
        if name == Self.dayName { self = .day; return }
        guard name.hasPrefix(Self.startPrefix) else { return nil }
        let digits = name.dropFirst(Self.startPrefix.count)
        guard digits.count == 4, let h = Int(digits.prefix(2)), let m = Int(digits.suffix(2)),
              let t = TimeOfDay(hour: h, minute: m) else { return nil }
        self = .start(t)
    }

    public var intervalStart: TimeOfDay {
        switch self {
        case .day: return TimeOfDay(minutesSinceMidnight: 0)!
        case .start(let t): return t
        }
    }

    /// The activities the current Tasks need. Past one-time Tasks are ignored.
    public static func desired(tasks: [LockInTask], today: DayKey) -> Set<ScheduledActivity> {
        var result: Set<ScheduledActivity> = [.day]
        for task in tasks where task.isRequired {
            guard let start = task.startTime else { continue }
            if case .once(let day) = task.schedule, day < today { continue }
            result.insert(.start(start))
        }
        return result
    }
}
