import Foundation

/// Lock Mode (see GLOSSARY): until `lockedUntil`, LockIn can only get stricter.
public struct LockMode: Hashable, Codable, Sendable {
    /// Durations offered, in days (v2's `LockSheet`).
    public static let durations = [1, 3, 7, 14, 30]

    public private(set) var lockedUntil: Date?

    public init() {}

    public func isActive(at now: Date) -> Bool {
        lockedUntil.map { now < $0 } ?? false
    }

    /// Starts or extends Lock Mode. It can't be ended or shortened.
    public mutating func lock(days: Int, now: Date) {
        let end = now.addingTimeInterval(TimeInterval(days) * 86_400)
        lockedUntil = max(end, lockedUntil ?? end)
    }
}

extension Document where Value == LockMode {
    public static let lockMode = Document("lockMode") { LockMode() }
}

/// What Lock Mode allows: anything that keeps or raises the bar, nothing that lowers it.
public enum LockPolicy {
    public enum Violation: CaseIterable, Hashable, Sendable {
        case deleteTask, makeOptional, removeWeekdays, changeOnceDay, laterStartTime, lowerStepTarget, changePlace, changeKind

        public var message: String {
            switch self {
            case .deleteTask: return "Tasks can't be deleted in Lock Mode."
            case .makeOptional: return "Required tasks can't be made optional in Lock Mode."
            case .removeWeekdays: return "Days can be added but not removed in Lock Mode."
            case .changeOnceDay: return "A one-time task's day can't change in Lock Mode."
            case .laterStartTime: return "The start time can only move earlier in Lock Mode."
            case .lowerStepTarget: return "The step goal can only go up in Lock Mode."
            case .changePlace: return "The place can't change in Lock Mode."
            case .changeKind: return "A step goal can't be added or removed in Lock Mode."
            }
        }
    }

    public static func allows(from old: LockInTask?, to new: LockInTask?) -> Bool {
        violations(from: old, to: new).isEmpty
    }

    /// `old == nil` is a new Task, `new == nil` a deletion.
    public static func violations(from old: LockInTask?, to new: LockInTask?) -> [Violation] {
        guard let old else { return [] }
        guard let new else { return [.deleteTask] }
        var result: [Violation] = []

        if old.isRequired && !new.isRequired { result.append(.makeOptional) }

        switch (old.schedule, new.schedule) {
        case (.weekly(let a), .weekly(let b)) where !b.isSuperset(of: a): result.append(.removeWeekdays)
        case (.weekly, .once): result.append(.removeWeekdays)
        case (.once(let a), .once(let b)) where a != b: result.append(.changeOnceDay)
        case (.once, .weekly): result.append(.changeOnceDay)
        default: break
        }

        // No Start Time means enforced from midnight, the earliest possible.
        switch (old.startTime, new.startTime) {
        case (nil, .some): result.append(.laterStartTime)
        case (.some(let a), .some(let b)) where b > a: result.append(.laterStartTime)
        default: break
        }

        switch (old.kind, new.kind) {
        case (.standard, .standard), (.standard, .location): break
        case (.stepGoal(let a), .stepGoal(let b)) where b < a: result.append(.lowerStepTarget)
        case (.stepGoal, .stepGoal): break
        case (.location(let a), .location(let b)) where a == b: break
        case (.location, _): result.append(.changePlace)
        default: result.append(.changeKind)
        }
        return result
    }

    /// Blocklist parts may gain items but never lose any.
    public static func allowsSetChange<T: Hashable>(from old: Set<T>, to new: Set<T>) -> Bool {
        new.isSuperset(of: old)
    }
}
