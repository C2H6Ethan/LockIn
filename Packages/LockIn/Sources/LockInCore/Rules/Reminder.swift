import Foundation

/// The daily reminder: sent only while Required Tasks are still owed, with the real count.
public enum Reminder {
    public struct Content: Equatable, Sendable {
        public let title: String
        public let body: String
    }

    public static func content(tasks: [LockInTask], completions: CompletionLog, day: DayKey, calendar: Calendar) -> Content? {
        let owed = Today(day: day, tasks: tasks, completions: completions, calendar: calendar).incompleteRequired
        switch owed.count {
        case 0: return nil
        case 1: return Content(title: "\(owed[0].task.title) is still open", body: "Finish it to keep your streak.")
        default: return Content(title: "\(owed.count) tasks left today", body: "Finish them to keep your streak.")
        }
    }
}
