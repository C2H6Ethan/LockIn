import Foundation

/// Every Task, in the order the Tasks screen shows them: Required, then Optional, each by title,
/// with one-time Tasks whose Day has passed last.
public struct TaskList: Sendable {
    public let required: [LockInTask]
    public let optional: [LockInTask]
    private let today: DayKey

    public init(tasks: [LockInTask], today: DayKey) {
        self.today = today
        let sorted = tasks.sorted { a, b in
            let pa = Self.isPast(a, today: today), pb = Self.isPast(b, today: today)
            if pa != pb { return !pa }
            return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
        }
        required = sorted.filter(\.isRequired)
        optional = sorted.filter { !$0.isRequired }
    }

    public var isEmpty: Bool { required.isEmpty && optional.isEmpty }

    /// A one-time Task whose Day is over. It stays listed (and editable) but is never due again.
    public func isPast(_ task: LockInTask) -> Bool { Self.isPast(task, today: today) }

    private static func isPast(_ task: LockInTask, today: DayKey) -> Bool {
        if case .once(let day) = task.schedule { return day < today }
        return false
    }
}
