import WidgetKit
import Foundation

/// Shared entry type for the LockIn home screen widget.
/// This file is compiled into both the main app target (for tests) and the LockInWidget target.
struct LockInWidgetEntry: TimelineEntry {
    let date: Date
    let incompleteCount: Int
    let totalCount: Int
    let streak: Int
    let taskTitles: [String]   // up to 2, for medium widget
    let allDone: Bool

    /// Builds a widget entry from a store snapshot.
    static func build(store: SharedStore = SharedStore(suiteName: Constants.AppGroup.id)) -> LockInWidgetEntry {
        let incomplete = store.buildTodayTasks()
        let todayString = Date().dateString
        let completedToday = store.completionLog[todayString]?.count ?? 0
        let total = incomplete.count + completedToday

        return LockInWidgetEntry(
            date: Date(),
            incompleteCount: incomplete.count,
            totalCount: total,
            streak: store.streakData.currentStreak,
            taskTitles: incomplete.prefix(2).map { $0.title },
            allDone: incomplete.isEmpty && total > 0
        )
    }
}
