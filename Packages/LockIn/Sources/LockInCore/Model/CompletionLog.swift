import Foundation

/// Which Tasks were completed on which Day.
public struct CompletionLog: Hashable, Codable, Sendable {
    public private(set) var completed: [DayKey: Set<LockInTask.ID>]

    public init(_ completed: [DayKey: Set<LockInTask.ID>] = [:]) {
        self.completed = completed
    }

    public func isCompleted(_ id: LockInTask.ID, on day: DayKey) -> Bool {
        completed[day]?.contains(id) ?? false
    }

    public func completedIDs(on day: DayKey) -> Set<LockInTask.ID> {
        completed[day] ?? []
    }

    public mutating func set(_ id: LockInTask.ID, completed isCompleted: Bool, on day: DayKey) {
        var ids = completed[day] ?? []
        if isCompleted { ids.insert(id) } else { ids.remove(id) }
        completed[day] = ids.isEmpty ? nil : ids
    }

    /// Drops every Day before `first`.
    public func pruned(keepingFrom first: DayKey) -> CompletionLog {
        CompletionLog(completed.filter { $0.key >= first })
    }
}
