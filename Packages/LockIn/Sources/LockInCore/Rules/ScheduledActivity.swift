import Foundation

/// A background activity LockIn needs registered with DeviceActivity.
/// All but `bypassEnd` repeat daily from their start time to the end of the Day.
public enum ScheduledActivity: Hashable, Sendable {
    /// Fires at midnight: finalises yesterday and re-evaluates the Shield.
    case day
    /// Fires at a Start Time shared by one or more Required Tasks.
    case start(TimeOfDay)
    /// Fires at the daily reminder time; the extension posts a reminder if Required Tasks are still owed.
    case reminder(TimeOfDay)
    /// One-shot, fires when a Bypass window ends so the extension can put the Shield back up.
    case bypassEnd(Date)

    public static let dayName = "day"
    static let startPrefix = "start-"
    static let reminderPrefix = "reminder-"
    static let bypassEndPrefix = "bypass-end-"

    public var name: String {
        switch self {
        case .day: return Self.dayName
        case .start(let t): return Self.startPrefix + Self.digits(t)
        case .reminder(let t): return Self.reminderPrefix + Self.digits(t)
        case .bypassEnd(let end): return Self.bypassEndPrefix + String(Int(end.timeIntervalSince1970))
        }
    }

    public init?(name: String) {
        if name == Self.dayName { self = .day; return }
        if let t = Self.time(in: name, after: Self.startPrefix) { self = .start(t); return }
        if let t = Self.time(in: name, after: Self.reminderPrefix) { self = .reminder(t); return }
        if name.hasPrefix(Self.bypassEndPrefix), let seconds = Int(name.dropFirst(Self.bypassEndPrefix.count)) {
            self = .bypassEnd(Date(timeIntervalSince1970: TimeInterval(seconds)))
            return
        }
        return nil
    }

    /// Daily start time of a repeating activity; `nil` for the one-shot `bypassEnd`.
    public var intervalStart: TimeOfDay? {
        switch self {
        case .day: return TimeOfDay(minutesSinceMidnight: 0)!
        case .start(let t), .reminder(let t): return t
        case .bypassEnd: return nil
        }
    }

    private static func digits(_ t: TimeOfDay) -> String {
        String(format: "%02d%02d", t.hour, t.minute)
    }

    private static func time(in name: String, after prefix: String) -> TimeOfDay? {
        guard name.hasPrefix(prefix) else { return nil }
        let digits = name.dropFirst(prefix.count)
        guard digits.count == 4, let h = Int(digits.prefix(2)), let m = Int(digits.suffix(2)) else { return nil }
        return TimeOfDay(hour: h, minute: m)
    }

    /// The activities the current Tasks and settings need. Past one-time Tasks are ignored.
    public static func desired(tasks: [LockInTask], reminderTime: TimeOfDay? = nil, today: DayKey, bypasses: BypassLog = BypassLog(), now: Date = Date()) -> Set<ScheduledActivity> {
        var result: Set<ScheduledActivity> = [.day]
        if let bypass = bypasses.pending(at: now) {
            // Bypass ends are whole seconds so the name round-trips.
            result.insert(.bypassEnd(Date(timeIntervalSince1970: bypass.end.timeIntervalSince1970.rounded(.down))))
        }
        if let reminderTime { result.insert(.reminder(reminderTime)) }
        for task in tasks where task.isRequired {
            guard let start = task.startTime else { continue }
            if case .once(let day) = task.schedule, day < today { continue }
            result.insert(.start(start))
        }
        return result
    }
}
