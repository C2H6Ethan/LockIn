import Foundation
import FamilyControls
import WidgetKit

/// Pure data/persistence layer. Not @Observable — ViewModels hold local copies.
final class SharedStore {

    static let shared = SharedStore()

    // MARK: - In-memory state

    private(set) var tasks: [Task] = []
    private(set) var completionLog: CompletionLog = [:]

    // MARK: - Computed

    /// Blocking tasks for today that are incomplete AND whose blocking window has started.
    var incompleteBlockingTasks: [TodayTask] {
        let nowComps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowMinutes = (nowComps.hour ?? 0) * 60 + (nowComps.minute ?? 0)
        return buildTodayTasks().filter { todayTask in
            guard todayTask.blocksApps else { return false }
            guard let task = tasks.first(where: { $0.id == todayTask.id }),
                  let start = task.blockingStartTime else { return true }
            let startMinutes = (start.hour ?? 0) * 60 + (start.minute ?? 0)
            return nowMinutes >= startMinutes
        }
    }

    var isLocked: Bool {
        guard let expiry = lockExpiresAt else { return false }
        return expiry > Date()
    }

    // MARK: - Persisted properties

    var selectedApps: FamilyActivitySelection {
        get {
            guard
                let data = defaults.data(forKey: Keys.selectedApps),
                let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Keys.selectedApps)
            defaults.synchronize()
        }
    }

    var unblockExpiresAt: Date? {
        get { defaults.object(forKey: Keys.unblockExpiresAt) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: Keys.unblockExpiresAt)
            } else {
                defaults.removeObject(forKey: Keys.unblockExpiresAt)
            }
            defaults.synchronize()
        }
    }

    var lockExpiresAt: Date? {
        get { defaults.object(forKey: Keys.lockExpiresAt) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: Keys.lockExpiresAt)
            } else {
                defaults.removeObject(forKey: Keys.lockExpiresAt)
            }
            defaults.synchronize()
        }
    }

    /// Snapshot of selectedApps taken at lock time. Used to enforce add-only behaviour while locked.
    var lockedAppTokens: FamilyActivitySelection? {
        get {
            guard
                let data = defaults.data(forKey: Keys.lockedAppTokens),
                let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return nil }
            return decoded
        }
        set {
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                defaults.set(data, forKey: Keys.lockedAppTokens)
            } else {
                defaults.removeObject(forKey: Keys.lockedAppTokens)
            }
            defaults.synchronize()
        }
    }

    // MARK: - Bypass (steps)

    /// Number of bypasses used today. Resets each new day via `recordBypassUsed`.
    var bypassCountToday: Int {
        defaults.integer(forKey: Keys.bypassCountToday)
    }

    /// Date string of the last recorded bypass. Used to detect day rollovers.
    var bypassCountDate: String {
        get { defaults.string(forKey: Keys.bypassCountDate) ?? "" }
        set {
            defaults.set(newValue, forKey: Keys.bypassCountDate)
            defaults.synchronize()
        }
    }

    /// Steps required for the walking bypass challenge today.
    /// Formula: `100 × (bypassCountToday + 1)`, capped at 1000. Resets on a new day.
    var stepsRequired: Int {
        let effectiveCount = bypassCountDate == Date().dateString ? bypassCountToday : 0
        return min(Constants.Stepping.stepsPerLevel * (effectiveCount + 1), Constants.Stepping.maxSteps)
    }

    /// Increments today's bypass counter.
    /// Caller is responsible for removing shields via `BlockingService.temporaryUnblock(duration:)`.
    func recordBypassUsed() {
        let today = Date().dateString
        if bypassCountDate != today {
            defaults.set(0, forKey: Keys.bypassCountToday)
        }
        let newCount = defaults.integer(forKey: Keys.bypassCountToday) + 1
        defaults.set(newCount, forKey: Keys.bypassCountToday)
        defaults.set(today, forKey: Keys.bypassCountDate)
        defaults.synchronize()
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set {
            defaults.set(newValue, forKey: Keys.hasCompletedOnboarding)
            defaults.synchronize()
        }
    }

    /// The daily reminder time. nil = never. Absent key = default 8 pm.
    var dailyReminderTime: Date? {
        get {
            if defaults.bool(forKey: Keys.reminderNever) { return nil }
            let hour = defaults.object(forKey: Keys.reminderHour) as? Int ?? Constants.DailyReminder.defaultHour
            let minute = defaults.object(forKey: Keys.reminderMinute) as? Int ?? 0
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            return Calendar.current.date(from: comps)
        }
        set {
            if let date = newValue {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                defaults.set(false, forKey: Keys.reminderNever)
                defaults.set(comps.hour ?? Constants.DailyReminder.defaultHour, forKey: Keys.reminderHour)
                defaults.set(comps.minute ?? 0, forKey: Keys.reminderMinute)
            } else {
                defaults.set(true, forKey: Keys.reminderNever)
            }
            defaults.synchronize()
        }
    }

    var streakData: StreakData {
        get {
            guard
                let data = defaults.data(forKey: Keys.streakData),
                let decoded = try? JSONDecoder().decode(StreakData.self, from: data)
            else { return StreakData() }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Keys.streakData)
            defaults.synchronize()
        }
    }

    // MARK: - Streak Freeze

    /// In-memory flag — set true when a missed day is detected and freeze is available.
    var pendingFreezeOffer: Bool = false

    var streakFreezeCount: Int {
        get { defaults.integer(forKey: Keys.streakFreezeCount) }
        set {
            defaults.set(newValue, forKey: Keys.streakFreezeCount)
            defaults.synchronize()
        }
    }

    var streakFreezeWeekString: String {
        get { defaults.string(forKey: Keys.streakFreezeWeekString) ?? "" }
        set {
            defaults.set(newValue, forKey: Keys.streakFreezeWeekString)
            defaults.synchronize()
        }
    }

    /// True if freeze is available this week. Automatically resets count to 1 on a new ISO week.
    var streakFreezeAvailable: Bool {
        let currentWeek = Date().isoWeekString
        if streakFreezeWeekString != currentWeek {
            streakFreezeCount = 1
            streakFreezeWeekString = currentWeek
        }
        return streakFreezeCount > 0
    }

    /// Consume the freeze: patch lastCompletedDate to yesterday so today's completion can extend the streak.
    func consumeFreeze() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var data = streakData
        data.lastCompletedDate = yesterday.dateString
        streakData = data
        streakFreezeCount = max(0, streakFreezeCount - 1)
        // Stamp the current week so streakFreezeAvailable won't reset the count back to 1.
        streakFreezeWeekString = Date().isoWeekString
        pendingFreezeOffer = false
    }

    /// Decline the freeze: reset streak to 0.
    func declineFreeze() {
        var data = streakData
        data.currentStreak = 0
        data.lastCompletedDate = nil
        streakData = data
        pendingFreezeOffer = false
    }

    // MARK: - Init

    private let defaults: UserDefaults

    init(suiteName: String = Constants.AppGroup.id) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        loadTasks()
        loadCompletionLog()
    }

    // MARK: - Task mutations

    func addTask(_ task: Task) {
        tasks.append(task)
        saveTasks()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func removeTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        saveTasks()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateTask(_ task: Task) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        saveTasks()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Completion mutations

    func completeTask(_ id: UUID, on dateString: String) {
        var set = completionLog[dateString, default: Set<UUID>()]
        set.insert(id)
        completionLog[dateString] = set
        saveCompletionLog()
    }

    func uncompleteTask(_ id: UUID, on dateString: String) {
        completionLog[dateString]?.remove(id)
        saveCompletionLog()
        // If today was already counted toward the streak, reverse it
        let todayString = Date().dateString
        if streakData.lastCompletedDate == todayString {
            var data = streakData
            data.currentStreak = max(0, data.currentStreak - 1)
            if data.currentStreak == 0 {
                data.lastCompletedDate = nil
            } else {
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                data.lastCompletedDate = yesterday.dateString
            }
            streakData = data
        }
    }

    // MARK: - Streak

    /// Increments the streak if ALL tasks visible today (scheduled + carryovers) are complete.
    func updateStreak(for dateString: String) {
        guard let date = Date.from(dateString: dateString) else { return }

        // All tasks in today's view (today's scheduled + any carryovers) must be done.
        let remaining = buildTodayTasks(on: date)
        guard remaining.isEmpty else { return }

        // Must have at least one task in the system (don't increment on task-free days).
        guard !tasks.isEmpty else { return }

        var data = streakData
        guard data.lastCompletedDate != dateString else { return } // already counted

        if let lastString = data.lastCompletedDate,
           let lastDate = Date.from(dateString: lastString),
           lastDate < date {
            // Consecutive if every day between lastCompletedDate (exclusive) and today (exclusive)
            // had no tasks scheduled. Task-free days are free passes — not the user's fault.
            var checkDate = Calendar.current.date(byAdding: .day, value: 1, to: lastDate)!
            var gapIsAllFree = true
            while checkDate < date {
                let weekday = checkDate.weekday
                let checkString = checkDate.dateString
                let hasWeeklyTask = tasks.contains(where: { $0.activeDays.contains(weekday) })
                let hasOnceTask = tasks.contains { task in
                    guard case .once(let startDateString) = task.recurrence else { return false }
                    return startDateString <= checkString
                }
                if hasWeeklyTask || hasOnceTask {
                    gapIsAllFree = false
                    break
                }
                checkDate = Calendar.current.date(byAdding: .day, value: 1, to: checkDate)!
            }
            data.currentStreak = gapIsAllFree ? data.currentStreak + 1 : 1
        } else {
            data.currentStreak = 1
        }

        data.longestStreak = max(data.longestStreak, data.currentStreak)
        data.lastCompletedDate = dateString
        streakData = data
    }

    /// Called on app open — resets the streak if any day with blocking tasks was missed.
    /// Only offers a freeze if EXACTLY 1 day was missed — multiple missed days get no freeze.
    /// Also cleans up once tasks completed on a previous day.
    func checkAndUpdateStreak(today: Date = Date()) {
        let todayString = today.dateString
        // Refresh freeze token using the injected date so tests stay deterministic.
        let currentWeek = today.isoWeekString
        if streakFreezeWeekString != currentWeek {
            streakFreezeCount = 1
            streakFreezeWeekString = currentWeek
        }
        let completedOnceTaskIDs = tasks
            .filter { $0.isOnce }
            .filter { task in
                guard let completedDate = completionLog.first(where: { $0.value.contains(task.id) })?.key else { return false }
                return completedDate < todayString
            }
            .map { $0.id }
        completedOnceTaskIDs.forEach { removeTask(id: $0) }
        guard streakData.currentStreak > 0 else { return }
        guard let lastString = streakData.lastCompletedDate,
              let lastDate = Date.from(dateString: lastString) else { return }

        if lastString == todayString { return } // already updated today

        // Scan ALL days from lastDate+1 up to yesterday and count missed days.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        var checkDate = Calendar.current.date(byAdding: .day, value: 1, to: lastDate)!
        var missedDayCount = 0

        while checkDate <= yesterday {
            let checkString = checkDate.dateString
            let weekday = checkDate.weekday

            // Weekly tasks scheduled for this weekday
            let weeklyTasks = tasks.filter { $0.activeDays.contains(weekday) }
            // Once tasks that started on or before this date and weren't completed yet
            let onceTasks = tasks.filter { task in
                guard case .once(let startDateString) = task.recurrence else { return false }
                guard startDateString <= checkString else { return false }
                return !completionLog.contains { dateKey, ids in dateKey <= checkString && ids.contains(task.id) }
            }

            let hasAnyTask = !weeklyTasks.isEmpty || !onceTasks.isEmpty
            if hasAnyTask {
                let completed = completionLog[checkString] ?? []
                let missedWeekly = weeklyTasks.contains { !completed.contains($0.id) }
                let missedOnce = !onceTasks.isEmpty
                if missedWeekly || missedOnce {
                    missedDayCount += 1
                }
            }

            checkDate = Calendar.current.date(byAdding: .day, value: 1, to: checkDate)!
        }

        guard missedDayCount > 0 else { return }

        if missedDayCount == 1 && streakFreezeCount > 0 {
            pendingFreezeOffer = true
        } else {
            var data = streakData
            data.currentStreak = 0
            streakData = data
        }
    }

    // MARK: - Today's tasks

    /// Returns incomplete tasks for `date`: all scheduled for that day that aren't done,
    /// plus incomplete carryovers (blocking and non-blocking) from the past 7 days.
    func buildTodayTasks(on date: Date = Date()) -> [TodayTask] {
        let todayWeekday = date.weekday
        let todayString = date.dateString

        // Track IDs already added to prevent duplicates between today + carryovers
        var seenIds = Set<UUID>()
        var result: [TodayTask] = []

        // Today's scheduled weekly tasks
        for task in tasks where task.activeDays.contains(todayWeekday) {
            seenIds.insert(task.id)
            let isCompleted = completionLog[todayString]?.contains(task.id) ?? false
            if !isCompleted {
                result.append(TodayTask(
                    id: task.id,
                    title: task.title,
                    blocksApps: task.blocksApps,
                    isCarryOver: false,
                    originalDay: nil,
                    scheduledDateString: todayString,
                    isOnce: false,
                    stepTarget: task.stepTarget
                ))
            }
        }

        // Carryover: incomplete weekly tasks from the past 7 days (blocking and non-blocking)
        for pastDate in date.previousDays(count: 7) {
            let pastWeekday = pastDate.weekday
            let pastString = pastDate.dateString

            for task in tasks where !task.isOnce {
                guard task.activeDays.contains(pastWeekday) else { continue }
                guard !(completionLog[pastString]?.contains(task.id) ?? false) else { continue }
                guard !seenIds.contains(task.id) else { continue }
                // Only carry over if the task existed on that past date
                guard Calendar.current.startOfDay(for: pastDate) >= Calendar.current.startOfDay(for: task.createdAt) else { continue }

                seenIds.insert(task.id)
                result.append(TodayTask(
                    id: task.id,
                    title: task.title,
                    blocksApps: task.blocksApps,
                    isCarryOver: true,
                    originalDay: pastDate.weekdayName,
                    scheduledDateString: pastString,
                    isOnce: false,
                    stepTarget: task.stepTarget
                ))
            }
        }

        // One-time tasks: appear from startDate onward until completed
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for task in tasks {
            guard case .once(let startDateString) = task.recurrence else { continue }
            guard startDateString <= todayString else { continue } // hasn't started yet
            guard !seenIds.contains(task.id) else { continue }
            // Skip if already completed (check all dates since once tasks log on today)
            let isCompleted = completionLog.values.contains { $0.contains(task.id) }
            guard !isCompleted else { continue }

            seenIds.insert(task.id)
            let isCarryOver = startDateString < todayString
            let originalDay: String? = isCarryOver
                ? Date.from(dateString: startDateString).map { dateFormatter.string(from: $0) }
                : nil

            result.append(TodayTask(
                id: task.id,
                title: task.title,
                blocksApps: task.blocksApps,
                isCarryOver: isCarryOver,
                originalDay: originalDay,
                scheduledDateString: todayString, // always log on today
                isOnce: true,
                stepTarget: task.stepTarget
            ))
        }

        return result
    }

    // MARK: - Persistence

    private func loadTasks() {
        guard
            let data = defaults.data(forKey: Keys.tasks),
            let decoded = try? JSONDecoder().decode([Task].self, from: data)
        else { return }
        tasks = decoded
    }

    private func saveTasks() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        defaults.set(data, forKey: Keys.tasks)
        defaults.synchronize()
    }

    private func loadCompletionLog() {
        guard
            let data = defaults.data(forKey: Keys.completionLog),
            let decoded = try? JSONDecoder().decode(CompletionLog.self, from: data)
        else { return }
        completionLog = decoded
    }

    private func saveCompletionLog() {
        guard let data = try? JSONEncoder().encode(completionLog) else { return }
        defaults.set(data, forKey: Keys.completionLog)
        defaults.synchronize()
    }

    // MARK: - Debug

    func injectStreak(_ streak: Int) {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        streakData = StreakData(
            currentStreak: streak,
            longestStreak: max(streak, streakData.longestStreak),
            lastCompletedDate: yesterday.dateString
        )
    }

#if DEBUG
    func resetForScreenshots() {
        tasks = []
        completionLog = [:]
        saveTasks()
        saveCompletionLog()
        streakData = StreakData()
    }
#endif

    // MARK: - Keys

    private enum Keys {
        static let tasks = "tasks"
        static let completionLog = "completionLog"
        static let streakData = "streakData"
        static let selectedApps = "selectedApps"
        static let unblockExpiresAt = "unblockExpiresAt"
        static let lockExpiresAt = "lockExpiresAt"
        static let lockedAppTokens = "lockedAppTokens"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let bypassCountToday = "bypassCountToday"
        static let bypassCountDate = "bypassCountDate"
        static let reminderNever = "reminderNever"
        static let reminderHour = "reminderHour"
        static let reminderMinute = "reminderMinute"
        static let streakFreezeCount = "streakFreezeCount"
        static let streakFreezeWeekString = "streakFreezeWeekString"
    }
}
