import Foundation
import LockInCore
import Observation

@MainActor
@Observable
final class TodayModel {
    private(set) var today: Today

    private let store: LockInStore
    private let calendar: Calendar
    private let now: () -> Date
    private let onChange: () -> Void

    init(store: LockInStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init, onChange: @escaping () -> Void) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.onChange = onChange
        self.today = Today(day: DayKey(now(), calendar: calendar), tasks: store.read(.tasks), completions: store.read(.completions), calendar: calendar)
    }

    /// Re-reads the store and the current Day. Call on foreground and at midnight.
    func reload() {
        today = Today(day: DayKey(now(), calendar: calendar), tasks: store.read(.tasks), completions: store.read(.completions), calendar: calendar)
    }

    func toggle(_ id: LockInTask.ID) {
        reload()
        guard let entry = today.all.first(where: { $0.task.id == id }) else { return }
        var log = store.read(.completions)
        log.set(id, completed: !entry.isCompleted, on: today.day)
        store.saveCompletions(log, today: today.day, calendar: calendar)
        reload()
        onChange()
    }

    var dateHeader: String {
        let date = today.day.startOfDay(in: calendar)
        var style = Date.FormatStyle(date: .omitted, time: .omitted).weekday(.wide).month(.abbreviated).day()
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = Locale(identifier: "en_US")
        return date.formatted(style)
    }

    /// "from 18:00" while a Required Task's Start Time is still ahead today.
    func subtitle(for task: LockInTask) -> String? {
        guard task.isRequired, let start = task.startTime,
              now() < today.day.instant(at: start, in: calendar) else { return nil }
        return "from \(start)"
    }
}
