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

    /// Whether any Task needs step counts at all.
    public static func isInUse(_ tasks: [LockInTask]) -> Bool {
        tasks.contains { $0.stepTarget != nil }
    }
}
