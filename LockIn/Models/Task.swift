import Foundation

/// Recurrence rule for a task.
enum TaskRecurrence: Codable, Equatable {
    case weekly(days: Set<Int>)     // Calendar weekday: 1=Sun, 2=Mon … 7=Sat
    case once(startDate: String)    // dateString — appears from this date onward until completed
}

/// Template for a recurring or one-time task. Persisted in SharedStore.
struct Task: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var recurrence: TaskRecurrence
    var blocksApps: Bool
    var createdAt: Date
    /// Non-nil for step goal tasks. Auto-completes when HealthKit reports ≥ this many steps today.
    var stepTarget: Int?
    /// When set, apps are only blocked after this time of day. nil = block all day.
    var blockingStartTime: DateComponents?

    init(
        id: UUID = UUID(),
        title: String,
        recurrence: TaskRecurrence,
        blocksApps: Bool = true,
        createdAt: Date = Date(),
        stepTarget: Int? = nil,
        blockingStartTime: DateComponents? = nil
    ) {
        self.id = id
        self.title = title
        self.recurrence = recurrence
        self.blocksApps = blocksApps
        self.createdAt = createdAt
        self.stepTarget = stepTarget
        self.blockingStartTime = blockingStartTime
    }

    /// Convenience initializer for weekly tasks — keeps existing call sites compiling.
    init(
        id: UUID = UUID(),
        title: String,
        activeDays: Set<Int>,
        blocksApps: Bool = true,
        createdAt: Date = Date(),
        stepTarget: Int? = nil,
        blockingStartTime: DateComponents? = nil
    ) {
        self.id = id
        self.title = title
        self.recurrence = .weekly(days: activeDays)
        self.blocksApps = blocksApps
        self.createdAt = createdAt
        self.stepTarget = stepTarget
        self.blockingStartTime = blockingStartTime
    }

    // MARK: - Computed helpers

    /// Active weekdays for weekly tasks; empty for one-time tasks.
    var activeDays: Set<Int> {
        if case .weekly(let days) = recurrence { return days }
        return []
    }

    var isOnce: Bool {
        if case .once = recurrence { return true }
        return false
    }

    var onceStartDate: String? {
        if case .once(let startDate) = recurrence { return startDate }
        return nil
    }
}

/// Tracks which tasks were completed on which dates.
/// [dateString ("2026-03-11")] → set of completed task IDs.
typealias CompletionLog = [String: Set<UUID>]

/// A task instance shown in Today's Tasks — either scheduled for today or carried over.
struct TodayTask: Identifiable, Equatable {
    let id: UUID
    let title: String
    let blocksApps: Bool
    let isCarryOver: Bool
    let originalDay: String?        // weekday name for weekly carryovers, formatted date for once
    let scheduledDateString: String // date to log completion against
    let isOnce: Bool                // true for .once(startDate:) tasks
    let stepTarget: Int?            // non-nil for step goal tasks

    init(
        id: UUID,
        title: String,
        blocksApps: Bool,
        isCarryOver: Bool,
        originalDay: String?,
        scheduledDateString: String,
        isOnce: Bool = false,
        stepTarget: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.blocksApps = blocksApps
        self.isCarryOver = isCarryOver
        self.originalDay = originalDay
        self.scheduledDateString = scheduledDateString
        self.isOnce = isOnce
        self.stepTarget = stepTarget
    }
}
