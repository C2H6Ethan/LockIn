import Foundation

/// Step-Goal Tasks (see GLOSSARY).
public enum StepGoal {
    /// The Step-Goal Tasks due on `day` whose target `stepsToday` has reached.
    public static func completions(tasks: [LockInTask], stepsToday: Int, day: DayKey, calendar: Calendar) -> Set<LockInTask.ID> {
        Set(tasks.filter { task in
            guard let target = task.stepTarget else { return false }
            return stepsToday >= target && task.isDue(on: day, calendar: calendar)
        }.map(\.id))
    }

    /// Today's steps so far, if the last total the app read is from today. `nil` means unknown: nothing read yet,
    /// HealthKit access denied, or the phone was locked (HealthKit is unreadable then).
    public static func progress(stored: StepsToday?, today: DayKey) -> Int? {
        guard let stored, stored.day == today else { return nil }
        return stored.total
    }

    /// Whether any Task needs step counts at all.
    public static func isInUse(_ tasks: [LockInTask]) -> Bool {
        tasks.contains { $0.stepTarget != nil }
    }
}

/// The last step total read for a Day, so Today can show progress without asking HealthKit itself.
public struct StepsToday: Hashable, Codable, Sendable {
    public let day: DayKey
    public let total: Int

    public init(day: DayKey, total: Int) {
        self.day = day
        self.total = total
    }
}

extension Document where Value == StepsToday? {
    public static let stepsToday = Document("stepsToday") { nil }
}
