import Foundation
import LockInCore
import Observation

@MainActor
@Observable
final class TodayModel {
    private(set) var today: Today
    /// The blocking status line (see GLOSSARY: Blocking status).
    private(set) var status: ShieldStatus
    /// Counts the ticks that turned blocking off. The success haptic fires on this, and only this.
    private(set) var shieldDrops = 0
    /// Today's step total as last read by the app, or `nil` when unknown.
    private(set) var stepsToday: Int?
    /// Tasks that exist but aren't due today, for the empty state.
    private(set) var tasksOnOtherDays = 0

    private let store: LockInStore
    private let calendar: Calendar
    private let now: () -> Date
    private let locate: () async -> Coordinate?
    /// Platform inputs: Screen Time authorization and whether the Blocklist is empty.
    private let screenTimeAllowed: () -> Bool
    private let blocklistIsEmpty: () -> Bool
    private let onChange: () -> Void
    /// Why a tap didn't complete a Location Task, shown under its row until the next tap.
    private var messages: [LockInTask.ID: String] = [:]
    private(set) var checkingLocation: Set<LockInTask.ID> = []

    init(store: LockInStore, calendar: Calendar = .current, now: @escaping () -> Date = Date.init,
         locate: @escaping () async -> Coordinate? = { nil },
         screenTimeAllowed: @escaping () -> Bool = { true }, blocklistIsEmpty: @escaping () -> Bool = { false },
         onChange: @escaping () -> Void) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.locate = locate
        self.screenTimeAllowed = screenTimeAllowed
        self.blocklistIsEmpty = blocklistIsEmpty
        self.onChange = onChange
        let day = DayKey(now(), calendar: calendar)
        self.today = Today(day: day, tasks: [], completions: CompletionLog(), calendar: calendar)
        self.status = ShieldStatus.current(now: now(), tasks: [], completions: CompletionLog(), bypasses: BypassLog(), lockMode: LockMode(),
                                           screenTimeAllowed: true, blocklistIsEmpty: false, calendar: calendar)
        reload()
    }

    /// Re-reads the store and the current Day. Call on foreground, at midnight and when authorization changes.
    func reload() {
        let now = now()
        let day = DayKey(now, calendar: calendar)
        let tasks = store.read(.tasks)
        let completions = store.read(.completions)
        today = Today(day: day, tasks: tasks, completions: completions, calendar: calendar)
        status = ShieldStatus.current(now: now, tasks: tasks, completions: completions, bypasses: store.read(.bypasses),
                                      lockMode: store.read(.lockMode), screenTimeAllowed: screenTimeAllowed(),
                                      blocklistIsEmpty: blocklistIsEmpty(), calendar: calendar)
        stepsToday = StepGoal.progress(stored: store.read(.stepsToday), today: day)
        tasksOnOtherDays = tasks.filter { !$0.isDue(on: day, calendar: calendar) && !TaskList(tasks: [$0], today: day).isPast($0) }.count
    }

    var statusText: ShieldStatus.Text { status.text(calendar: calendar) }

    /// Completes or un-completes a Task. Completing a Location Task may need a location fix first;
    /// the returned Task is that check, so callers (and tests) can await it.
    @discardableResult
    func toggle(_ id: LockInTask.ID) -> Task<Void, Never>? {
        reload()
        messages[id] = nil
        guard let entry = today.all.first(where: { $0.task.id == id }), entry.task.canCompleteManually else { return nil }
        let task = entry.task
        let day = today.day
        guard !entry.isCompleted,
              let place = task.place,
              !LocationRule.canComplete(task: task, visits: store.read(.visits), currentLocation: nil, day: day)
        else {
            setCompleted(id, !entry.isCompleted, on: day)
            return nil
        }
        checkingLocation.insert(id)
        return Task {
            let fix = await locate()
            checkingLocation.remove(id)
            if LocationRule.canComplete(task: task, visits: store.read(.visits), currentLocation: fix, day: day) {
                var visits = store.read(.visits)
                visits.record(id, on: day, calendar: calendar)
                store.write(visits, to: .visits)
                setCompleted(id, true, on: day)
            } else {
                messages[id] = fix == nil ? "Couldn't find your location. Try again." : "Not at \(place.name) yet today."
            }
        }
    }

    func message(for task: LockInTask) -> String? { messages[task.id] }

    private func setCompleted(_ id: LockInTask.ID, _ completed: Bool, on day: DayKey) {
        let tasks = store.read(.tasks)
        var log = store.read(.completions)
        let wasOwed = !ShieldDecision.owedTasks(at: now(), tasks: tasks, completions: log, calendar: calendar).isEmpty
        log.set(id, completed: completed, on: day)
        store.saveCompletions(log, today: day, calendar: calendar)
        if completed, wasOwed, ShieldDecision.owedTasks(at: now(), tasks: tasks, completions: log, calendar: calendar).isEmpty {
            shieldDrops += 1
        }
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

    /// Consecutive Kept Days including today once it's kept.
    var streak: Int {
        let settings = store.read(.settings)
        return Streak.current(records: store.read(.dayRecords), today: today, firstDay: settings.firstDay, seed: settings.streakSeed, calendar: calendar)
    }

    /// True once, the first time the Streak reaches a week; records that it asked.
    func consumeReviewRequest() -> Bool {
        var settings = store.read(.settings)
        guard ReviewPrompt.shouldRequest(streak: streak, alreadyRequested: settings.hasRequestedReview) else { return false }
        settings.hasRequestedReview = true
        store.write(settings, to: .settings)
        return true
    }

    var streakLabel: String? {
        streak > 0 ? "\(streak)-day streak" : nil
    }

    /// How far a Step-Goal Task is, 0...1, or `nil` when today's total is unknown.
    func stepProgress(for task: LockInTask) -> Double? {
        guard let target = task.stepTarget, target > 0, let steps = stepsToday else { return nil }
        return min(1, Double(steps) / Double(target))
    }

    /// "from 18:00" while a Required Task's Start Time is still ahead today.
    /// Step goal or place first, then a Start Time that hasn't passed yet.
    func subtitle(for task: LockInTask) -> String? {
        var parts: [String] = []
        if let target = task.stepTarget {
            parts.append(stepsToday.map { "\(min($0, target).formatted()) of \(target.formatted()) steps" } ?? "\(target.formatted()) steps")
        }
        if let place = task.place { parts.append(place.name) }
        if task.isRequired, let start = task.startTime, now() < today.day.instant(at: start, in: calendar) {
            parts.append("blocks from \(start)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
