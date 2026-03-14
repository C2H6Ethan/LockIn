import Foundation
import Observation
import WidgetKit

@Observable
final class TodayViewModel {

    // MARK: - State

    var todayTasks: [TodayTask] = []
    var streak: Int = 0
    var showingAddTask = false
    private(set) var hasCompletedTaskToday = false
    private(set) var streakAnimationTrigger = 0
    private(set) var stepsToday: Int = 0
    private(set) var pendingFreezeOffer = false

    // MARK: - Computed

    var allBlockingDone: Bool {
        !todayTasks.contains { $0.blocksApps }
    }

    var isHealthKitAvailable: Bool { stepProvider.isAvailable }

    // MARK: - Dependencies

    private let store: SharedStore
    private let blocking: BlockingService
    private let stepProvider: any StepProviding
    private var notificationObserver: (any NSObjectProtocol)?

    // MARK: - Init

    init(
        store: SharedStore = .shared,
        blocking: BlockingService = .shared,
        stepProvider: any StepProviding = StepCountService.shared
    ) {
        self.store = store
        self.blocking = blocking
        self.stepProvider = stepProvider
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .habitsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sync()
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stepProvider.stopObserving()
    }

    // MARK: - Actions

    func onAppear() {
        store.checkAndUpdateStreak()
        sync()
        // Defer freeze offer by one run loop — fullScreenCover won't present
        // reliably if isPresented becomes true during onAppear.
        if store.pendingFreezeOffer {
            DispatchQueue.main.async { [weak self] in
                self?.pendingFreezeOffer = true
            }
        }
        refreshStepCounts()
        stepProvider.startObserving { [weak self] in
            self?.refreshStepCounts()
        }
    }

    func addTask(title: String, recurrence: TaskRecurrence, blocksApps: Bool, stepTarget: Int? = nil, blockingStartTime: DateComponents? = nil) {
        let task = Task(title: title, recurrence: recurrence, blocksApps: blocksApps, stepTarget: stepTarget, blockingStartTime: blockingStartTime)
        store.addTask(task)
        // Decrement streak for any task added for today (blocking or not)
        let todayString = Date().dateString
        let shouldDecrement: Bool = {
            switch recurrence {
            case .weekly(let days):
                let todayWeekday = Calendar.current.component(.weekday, from: Date())
                return days.contains(todayWeekday) && store.streakData.lastCompletedDate == todayString
            case .once(let startDate):
                return startDate == todayString && store.streakData.lastCompletedDate == todayString
            }
        }()
        if shouldDecrement {
            var data = store.streakData
            data.currentStreak = max(0, data.currentStreak - 1)
            if data.currentStreak == 0 {
                data.lastCompletedDate = nil
            } else {
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                data.lastCompletedDate = yesterday.dateString
            }
            store.streakData = data
        }
        showingAddTask = false
        blocking.updateShieldsForCurrentHabitState()
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)
        sync()
    }

    /// Convenience wrapper for weekly tasks — keeps existing call sites compiling.
    func addTask(title: String, activeDays: Set<Int>, blocksApps: Bool) {
        addTask(title: title, recurrence: .weekly(days: activeDays), blocksApps: blocksApps)
    }

    func consumeFreeze() {
        store.consumeFreeze()
        pendingFreezeOffer = false
        sync()
        blocking.updateShieldsForCurrentHabitState()
    }

    func declineFreeze() {
        store.declineFreeze()
        pendingFreezeOffer = false
        sync()
        blocking.updateShieldsForCurrentHabitState()
    }

    func completeTask(_ task: TodayTask) {
        let prevStreak = store.streakData.currentStreak
        // Log on the task's original scheduled date (past date for carryovers).
        store.completeTask(task.id, on: task.scheduledDateString)
        store.updateStreak(for: Date().dateString)
        todayTasks.removeAll { $0.id == task.id }
        hasCompletedTaskToday = true
        blocking.updateShieldsForCurrentHabitState()
        SchedulingService.shared.rescheduleReminderIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
        sync()
        if store.streakData.currentStreak > prevStreak {
            streakAnimationTrigger += 1
        }
    }

    // MARK: - Step goals

    func refreshStepCounts() {
        _Concurrency.Task { [weak self] in
            await self?.refreshStepCounts()
        }
    }

    /// Async version — awaitable from tests and internal callers.
    @MainActor
    func refreshStepCounts() async {
        let steps = await stepProvider.stepsToday()
        stepsToday = steps
        autoCompleteStepTasksIfNeeded()
    }

    func autoCompleteStepTasksIfNeeded() {
        let toComplete = todayTasks.filter { task in
            guard let target = task.stepTarget else { return false }
            return stepsToday >= target
        }
        for task in toComplete {
            completeTask(task)
        }
    }

    // MARK: - Private

    private func sync() {
        let all = store.buildTodayTasks()
        // Carryovers first, then today's scheduled tasks
        todayTasks = all.sorted { a, b in
            if a.isCarryOver && !b.isCarryOver { return true }
            return false
        }
        streak = store.streakData.currentStreak
        hasCompletedTaskToday = !(store.completionLog[Date().dateString]?.isEmpty ?? true)
    }
}
