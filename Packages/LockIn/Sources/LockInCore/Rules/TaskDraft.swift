import Foundation

/// The editable form of a Task, with the rules that decide whether it can be saved.
public struct TaskDraft: Equatable, Sendable {
    public enum Repeats: Equatable, Sendable { case weekly, once }

    /// How the Task gets done (see GLOSSARY: Completes by). Maps 1:1 onto `LockInTask.Kind`.
    public enum CompletesBy: Hashable, Sendable, CaseIterable { case tickOff, steps, place }

    public enum ValidationError: Equatable, Sendable {
        case emptyTitle, noWeekdays, dayInPast, tooManyStartTimes, invalidStepTarget, noPlace, tooManyPlaces

        public var message: String {
            switch self {
            case .emptyTitle: return "Give the task a name."
            case .noWeekdays: return "Pick at least one day."
            case .dayInPast: return "Pick today or a later day."
            case .tooManyStartTimes: return "You can use up to \(TaskDraft.maxDistinctStartTimes) different start times."
            case .noPlace: return "Pick a place."
            case .tooManyPlaces: return "You can use up to \(LocationRule.maxPlaces) places."
            case .invalidStepTarget: return "Pick a goal between \(TaskDraft.stepTargetRange.lowerBound) and \(TaskDraft.stepTargetRange.upperBound.formatted()) steps."
            }
        }
    }

    /// iOS allows about 20 DeviceActivity schedules per app; this leaves room for the day, reminder and Bypass ones.
    public static let maxDistinctStartTimes = 15
    public static let stepTargetRange = 100...100_000
    public static let defaultStepTarget = 8000

    public var title = ""
    public var requirement = Requirement.required
    public var repeats = Repeats.weekly
    public var weekdays = Set(Weekday.allCases)
    /// Used when `repeats == .once`. `nil` means today.
    public var onceDay: DayKey?
    /// Only Required Tasks keep one; Optional Tasks save without it.
    public var startTime: TimeOfDay?
    public var completesBy = CompletesBy.tickOff
    /// Used when `completesBy == .steps`; kept while switching so the choice can be undone.
    public var stepTarget = TaskDraft.defaultStepTarget
    /// Used when `completesBy == .place`.
    public var place: Place?

    public init() {}

    public init(task: LockInTask, today: DayKey) {
        title = task.title
        requirement = task.requirement
        startTime = task.startTime
        switch task.kind {
        case .standard: completesBy = .tickOff
        case .stepGoal(let target):
            completesBy = .steps
            stepTarget = target
        case .location(let place):
            completesBy = .place
            self.place = place
        }
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
        switch completesBy {
        case .tickOff: break
        case .steps where !Self.stepTargetRange.contains(stepTarget): errors.append(.invalidStepTarget)
        case .steps: break
        case .place where place == nil: errors.append(.noPlace)
        case .place:
            if otherTasks.filter({ $0.place != nil }).count >= LocationRule.maxPlaces { errors.append(.tooManyPlaces) }
        }
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
        let kind: LockInTask.Kind
        switch completesBy {
        case .tickOff: kind = .standard
        case .steps: kind = .stepGoal(target: stepTarget)
        case .place: kind = place.map { .location($0) } ?? .standard
        }
        let startTime = requirement == .required ? self.startTime : nil
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
