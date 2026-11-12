import Foundation
import LockInCore
import Observation

/// Every Task, for the Tasks screen. Order comes from core `TaskList`.
@MainActor
@Observable
final class TasksModel {
    private(set) var list: TaskList

    private let store: LockInStore
    private let calendar: Calendar
    private let now: () -> Date

    init(store: LockInStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.list = TaskList(tasks: [], today: DayKey(now(), calendar: calendar))
        reload()
    }

    func reload() {
        list = TaskList(tasks: store.read(.tasks), today: today)
    }

    private var today: DayKey { DayKey(now(), calendar: calendar) }

    /// "Every day", "Weekdays", "Mon, Wed, Fri" or "Thu, Nov 12", then the kind and a Required Task's Start Time:
    /// "Every day · 8,000 steps · blocks from 18:00".
    func describe(_ task: LockInTask) -> String {
        var parts: [String] = []
        switch task.schedule {
        case .weekly(let days):
            parts.append(Self.describe(weekdays: days))
        case .once(let day):
            if day == today {
                parts.append("Today")
            } else {
                var style = Date.FormatStyle(date: .omitted, time: .omitted).weekday(.abbreviated).month(.abbreviated).day()
                style.calendar = calendar
                style.timeZone = calendar.timeZone
                style.locale = Locale(identifier: "en_US")
                parts.append(day.startOfDay(in: calendar).formatted(style))
            }
        }
        if let target = task.stepTarget { parts.append("\(target.formatted()) steps") }
        if let place = task.place { parts.append(place.name) }
        if task.isRequired, let start = task.startTime { parts.append("blocks from \(start)") }
        return parts.joined(separator: " · ")
    }

    static func describe(weekdays: Set<Weekday>) -> String {
        let workweek: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        if weekdays == Set(Weekday.allCases) { return "Every day" }
        if weekdays == workweek { return "Weekdays" }
        if weekdays == [.saturday, .sunday] { return "Weekends" }
        let order: [(Weekday, String)] = [(.monday, "Mon"), (.tuesday, "Tue"), (.wednesday, "Wed"), (.thursday, "Thu"), (.friday, "Fri"), (.saturday, "Sat"), (.sunday, "Sun")]
        return order.filter { weekdays.contains($0.0) }.map(\.1).joined(separator: ", ")
    }
}
