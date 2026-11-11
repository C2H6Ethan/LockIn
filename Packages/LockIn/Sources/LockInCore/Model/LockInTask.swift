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
    public var kind: Kind

    /// What completes a Task (see GLOSSARY: Kinds of Task).
    public enum Kind: Hashable, Codable, Sendable {
        /// Completed by the user.
        case standard
        /// Completes itself once the Day's steps reach `target` (Step-Goal Task).
        case stepGoal(target: Int)
    }

    public init(id: ID = UUID(), title: String, schedule: Schedule, requirement: Requirement, startTime: TimeOfDay? = nil, createdOn: DayKey, kind: Kind = .standard) {
        self.id = id
        self.title = title
        self.schedule = schedule
        self.requirement = requirement
        self.startTime = startTime
        self.createdOn = createdOn
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, schedule, requirement, startTime, createdOn, kind
    }

    /// `kind` was added after the first v3 builds; Tasks stored without it are standard.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        schedule = try c.decode(Schedule.self, forKey: .schedule)
        requirement = try c.decode(Requirement.self, forKey: .requirement)
        startTime = try c.decodeIfPresent(TimeOfDay.self, forKey: .startTime)
        createdOn = try c.decode(DayKey.self, forKey: .createdOn)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .standard
    }

    public var isRequired: Bool { requirement == .required }

    public var stepTarget: Int? {
        if case .stepGoal(let target) = kind { return target }
        return nil
    }

    /// Step-Goal Tasks complete themselves; ticking them off by hand would defeat the point.
    public var canCompleteManually: Bool { kind == .standard }

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
