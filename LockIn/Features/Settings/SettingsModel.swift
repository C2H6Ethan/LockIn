import Foundation
import LockInCore
import Observation

@MainActor
@Observable
final class SettingsModel {
    private(set) var tasks: [LockInTask] = []
    private(set) var settings: Settings

    private let store: LockInStore
    private let calendar: Calendar
    private let now: () -> Date
    private let onChange: () -> Void

    init(store: LockInStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init, onChange: @escaping () -> Void) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.onChange = onChange
        self.settings = store.read(.settings)
        reload()
    }

    func reload() {
        tasks = store.read(.tasks)
        settings = store.read(.settings)
    }

    private var today: DayKey { DayKey(now(), calendar: calendar) }

    /// When Lock Mode ends, if it's on.
    var lockedUntil: Date? {
        let mode = store.read(.lockMode)
        return mode.isActive(at: now()) ? mode.lockedUntil : nil
    }

    /// Starts or extends Lock Mode. There is no way to end it early.
    func lock(days: Int) {
        var mode = store.read(.lockMode)
        mode.lock(days: days, now: now())
        store.write(mode, to: .lockMode)
        reload()
    }

    var requiredTasks: [LockInTask] { sorted(tasks.filter(\.isRequired)) }
    var optionalTasks: [LockInTask] { sorted(tasks.filter { !$0.isRequired }) }

    /// Current Tasks by title; one-time Tasks whose Day has passed go last.
    private func sorted(_ list: [LockInTask]) -> [LockInTask] {
        list.sorted { a, b in
            let pa = isPast(a), pb = isPast(b)
            if pa != pb { return !pa }
            return a.title.localizedCompare(b.title) == .orderedAscending
        }
    }

    private func isPast(_ task: LockInTask) -> Bool {
        if case .once(let day) = task.schedule { return day < today }
        return false
    }

    var reminderTime: TimeOfDay? {
        get { settings.reminderTime }
        set {
            settings.reminderTime = newValue
            store.write(settings, to: .settings)
            onChange()
        }
    }

    /// "Every day", "Weekdays", "Mon, Wed, Fri" or "Thu, Nov 12", plus " · from 18:00".
    func describe(_ task: LockInTask) -> String {
        var text: String
        switch task.schedule {
        case .weekly(let days):
            text = Self.describe(weekdays: days)
        case .once(let day):
            if day == today {
                text = "Today"
            } else {
                var style = Date.FormatStyle(date: .omitted, time: .omitted).weekday(.abbreviated).month(.abbreviated).day()
                style.calendar = calendar
                style.timeZone = calendar.timeZone
                style.locale = Locale(identifier: "en_US")
                text = day.startOfDay(in: calendar).formatted(style)
            }
        }
        if let start = task.startTime { text += " · from \(start)" }
        return text
    }

    static func describe(weekdays: Set<Weekday>) -> String {
        let workweek: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
        if weekdays == Set(Weekday.allCases) { return "Every day" }
        if weekdays == workweek { return "Weekdays" }
        if weekdays == [.saturday, .sunday] { return "Weekends" }
        let order: [(Weekday, String)] = [(.monday, "Mon"), (.tuesday, "Tue"), (.wednesday, "Wed"), (.thursday, "Thu"), (.friday, "Fri"), (.saturday, "Sat"), (.sunday, "Sun")]
        return order.filter { weekdays.contains($0.0) }.map(\.1).joined(separator: ", ")
    }

    var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }
}
