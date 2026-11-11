import Foundation
import LockInCore
import Observation

@MainActor
@Observable
final class TaskFormModel {
    static let startTimeChoices: [TimeOfDay] = stride(from: 0, through: TimeOfDay.latest.minutesSinceMidnight, by: TimeOfDay.step)
        .compactMap { TimeOfDay(minutesSinceMidnight: $0) }

    private static let stepTargetPresets = Array(stride(from: 1000, through: 30000, by: 1000))

    /// Presets, plus the current value if it isn't one (e.g. imported from v2).
    var stepTargetChoices: [Int] {
        let target = draft.stepTarget
        guard !Self.stepTargetPresets.contains(target) else { return Self.stepTargetPresets }
        return (Self.stepTargetPresets + [target]).sorted()
    }

    var draft: TaskDraft
    let existing: LockInTask?

    private let store: LockInStore
    private let calendar: Calendar
    private let now: () -> Date
    private let onChange: () -> Void

    init(editing existing: LockInTask?, store: LockInStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init, onChange: @escaping () -> Void) {
        self.existing = existing
        self.store = store
        self.calendar = calendar
        self.now = now
        self.onChange = onChange
        let today = DayKey(now(), calendar: calendar)
        self.draft = existing.map { TaskDraft(task: $0, today: today) } ?? TaskDraft()
    }

    var isEditing: Bool { existing != nil }
    var today: DayKey { DayKey(now(), calendar: calendar) }

    private var otherTasks: [LockInTask] {
        store.read(.tasks).filter { $0.id != existing?.id }
    }

    var errors: [TaskDraft.ValidationError] {
        draft.validate(otherTasks: otherTasks, today: today)
    }

    var canSave: Bool { errors.isEmpty && lockViolations.isEmpty }

    /// Why Save is off, shown under the name from the start: the first validation error, else the first Lock Mode violation.
    var saveHint: String? {
        errors.first?.message ?? lockViolations.first?.message
    }

    // MARK: Lock Mode

    /// When Lock Mode ends, if it's on.
    var lockedUntil: Date? {
        let mode = store.read(.lockMode)
        return mode.isActive(at: now()) ? mode.lockedUntil : nil
    }

    /// What this edit would weaken; empty outside Lock Mode.
    var lockViolations: [LockPolicy.Violation] {
        guard lockedUntil != nil, let existing,
              let edited = draft.makeTask(existing: existing, today: today, otherTasks: otherTasks)
        else { return [] }
        return LockPolicy.violations(from: existing, to: edited)
    }

    var canDelete: Bool { isEditing && lockedUntil == nil }

    /// Returns whether the Task was saved.
    @discardableResult
    func save() -> Bool {
        let others = otherTasks
        guard lockViolations.isEmpty,
              let task = draft.makeTask(existing: existing, today: today, otherTasks: others) else { return false }
        var tasks = store.read(.tasks)
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
        store.write(tasks, to: .tasks)
        onChange()
        return true
    }

    func delete() {
        guard let existing, canDelete else { return }
        store.write(store.read(.tasks).filter { $0.id != existing.id }, to: .tasks)
        onChange()
    }

    /// The once-Day as a Date for the date picker, and back.
    var onceDate: Date {
        get { (draft.onceDay ?? today).startOfDay(in: calendar) }
        set { draft.onceDay = DayKey(newValue, calendar: calendar) }
    }
}
