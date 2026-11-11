import Foundation

/// A Task (see GLOSSARY). Named `LockInTask` to avoid clashing with Swift's `Task`.
public struct LockInTask: Identifiable, Hashable, Codable, Sendable {
    public typealias ID = UUID

    public var id: ID
    public var title: String
    public var schedule: Schedule
    public var requirement: Requirement
    public var startTime: TimeOfDay?
    /// A Task is never due before the Day it was created.
    public var createdOn: DayKey

    public init(id: ID = UUID(), title: String, schedule: Schedule, requirement: Requirement, startTime: TimeOfDay? = nil, createdOn: DayKey) {
        self.id = id
        self.title = title
        self.schedule = schedule
        self.requirement = requirement
        self.startTime = startTime
        self.createdOn = createdOn
    }

    public var isRequired: Bool { requirement == .required }

    public func isDue(on day: DayKey, calendar: Calendar) -> Bool {
        guard day >= createdOn else { return false }
        switch schedule {
        case .weekly(let days): return days.contains(day.weekday(in: calendar))
        case .once(let date): return date == day
        }
    }

    /// The instant on `day` from which an incomplete Required Task shields. Midnight when there is no Start Time.
    public func enforcementStart(on day: DayKey, calendar: Calendar) -> Date {
        day.instant(at: startTime ?? TimeOfDay(minutesSinceMidnight: 0)!, in: calendar)
    }
}

public enum Schedule: Hashable, Codable, Sendable {
    case weekly(Set<Weekday>)
    case once(DayKey)
}

public enum Requirement: String, Codable, Sendable {
    case required
    case optional
}
