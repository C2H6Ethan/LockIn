import Foundation

/// The editable form of a Task, with the rules that decide whether it can be saved.
public struct TaskDraft: Equatable, Sendable {
    public enum Repeats: Equatable, Sendable { case weekly, once }

    public enum ValidationError: Equatable, Sendable {
        case emptyTitle, noWeekdays, dayInPast, tooManyStartTimes, invalidStepTarget, stepGoalAndPlace, tooManyPlaces

        public var message: String {
            switch self {
            case .emptyTitle: return "Give the task a name."
            case .noWeekdays: return "Pick at least one day."
            case .dayInPast: return "Pick today or a later day."
            case .tooManyStartTimes: return "You can use up to \(TaskDraft.maxDistinctStartTimes) different start times."
            case .stepGoalAndPlace: return "A task can have a step goal or a place, not both."
            case .tooManyPlaces: return "You can use up to \(LocationRule.maxPlaces) places."
            case .invalidStepTarget: return "Pick a goal between \(TaskDraft.stepTargetRange.lowerBound) and \(TaskDraft.stepTargetRange.upperBound.formatted()) steps."
            }
        }
    }

    /// iOS allows about 20 DeviceActivity schedules per app; this leaves room for the day, reminder and Bypass ones.
    public static let maxDistinctStartTimes = 15
    public static let stepTargetRange = 100...100_000

    public var title = ""
    public var requirement = Requirement.required
    public var repeats = Repeats.weekly
    public var weekdays = Set(Weekday.allCases)
    /// Used when `repeats == .once`. `nil` means today.
    public var onceDay: DayKey?
    public var startTime: TimeOfDay?
    /// Non-nil makes this a Step-Goal Task.
    public var stepTarget: Int?
    /// Non-nil makes this a Location Task.
    public var place: Place?

    public init() {}

    public init(task: LockInTask, today: DayKey) {
        title = task.title
        requirement = task.requirement
        startTime = task.startTime
        stepTarget = task.stepTarget
        place = task.place
        switch task.schedule {
        case .weekly(let days):
            repeats = .weekly
            weekdays = days
        case .once(let day):
            repeats = .once
            onceDay = day
        }
    }

    public func validate(otherTasks: [LockInTask], today: DayKey) -> [ValidationError] {
        var errors: [ValidationError] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(.emptyTitle) }
        switch repeats {
        case .weekly where weekdays.isEmpty: errors.append(.noWeekdays)
        case .once where (onceDay ?? today) < today: errors.append(.dayInPast)
        default: break
        }
        if let stepTarget, !Self.stepTargetRange.contains(stepTarget) { errors.append(.invalidStepTarget) }
        if stepTarget != nil, place != nil { errors.append(.stepGoalAndPlace) }
        if place != nil, otherTasks.filter({ $0.place != nil }).count >= LocationRule.maxPlaces { errors.append(.tooManyPlaces) }
        if requirement == .required, let startTime {
            let existing = Set(otherTasks.filter(\.isRequired).compactMap(\.startTime))
            if !existing.contains(startTime), existing.count >= Self.maxDistinctStartTimes {
                errors.append(.tooManyStartTimes)
            }
        }
        return errors
    }

    /// The Task to save, or `nil` if the draft is invalid. Editing keeps the Task's id and creation Day.
    public func makeTask(existing: LockInTask?, today: DayKey, otherTasks: [LockInTask] = []) -> LockInTask? {
        guard validate(otherTasks: otherTasks, today: today).isEmpty else { return nil }
        let schedule: Schedule = repeats == .weekly ? .weekly(weekdays) : .once(onceDay ?? today)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind: LockInTask.Kind = stepTarget.map { .stepGoal(target: $0) } ?? place.map { .location($0) } ?? .standard
        if var task = existing {
            task.title = cleanTitle
            task.schedule = schedule
            task.requirement = requirement
            task.startTime = startTime
            task.kind = kind
            return task
        }
        return LockInTask(title: cleanTitle, schedule: schedule, requirement: requirement, startTime: startTime, createdOn: today, kind: kind)
    }
}
