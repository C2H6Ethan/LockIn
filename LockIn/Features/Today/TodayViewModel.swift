import CoreLocation
import Foundation
import Observation
import WidgetKit

@Observable
final class TodayViewModel {

    // MARK: - State

    var todayTasks: [TodayTask] = []
    var completedTasks: [TodayTask] = []
    var streak: Int = 0
    var showingAddTask = false
    var hasCompletedTaskToday = false
    private(set) var streakAnimationTrigger = 0
    var stepsToday: Int = 0
    private(set) var pendingFreezeOffer = false
    private(set) var showUndoToast = false
    private(set) var undoTaskID: UUID?
    private var undoTask: TodayTask?
    private var undoTimer: Timer?
    /// Set to the task ID when location verification fails. Drives error state in TaskRowView.
    private(set) var locationVerificationFailed: UUID?
    /// True after first successful location task completion when "When In Use" — prompts upgrade to Always.
    var showLocationUpgradePrompt = false

    // MARK: - Computed

    var allBlockingDone: Bool {
        !todayTasks.contains { $0.blocksApps }
    }

    private(set) var locationAlwaysAuthorized = false

    var isHealthKitAvailable: Bool { stepProvider.isAvailable }

    // MARK: - Dependencies

    private let store: SharedStore
    private let blocking: BlockingService
    private let stepProvider: any StepProviding
    private let locationVerifier: any LocationVerifying
    private var notificationObserver: (any NSObjectProtocol)?

    // MARK: - Init

    init(
        store: SharedStore = .shared,
        blocking: BlockingService = .shared,
        stepProvider: any StepProviding = StepCountService.shared,
        locationVerifier: (any LocationVerifying)? = nil
    ) {
        self.locationVerifier = locationVerifier ?? LocationVerificationService.shared
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
        if store.pendingFreezeOffer {
            ActivityLog.log("FREEZE_OFFERED")
        }
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

    func addTask(title: String, recurrence: TaskRecurrence, blocksApps: Bool, stepTarget: Int? = nil, blockingStartTime: DateComponents? = nil, location: TaskLocation? = nil) {
        let task = Task(title: title, recurrence: recurrence, blocksApps: blocksApps, stepTarget: stepTarget, blockingStartTime: blockingStartTime, location: location)
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
        ActivityLog.log("TASK_ADDED: \"\(title)\" blocksApps=\(blocksApps) decremented=\(shouldDecrement)")
        sync()
    }

    /// Convenience wrapper for weekly tasks — keeps existing call sites compiling.
    func addTask(title: String, activeDays: Set<Int>, blocksApps: Bool) {
        addTask(title: title, recurrence: .weekly(days: activeDays), blocksApps: blocksApps)
    }

    func upgradeToAlwaysLocation() {
        locationVerifier.requestAlwaysAuthorization()
        showLocationUpgradePrompt = false
    }

    func consumeFreeze() {
        store.consumeFreeze()
        pendingFreezeOffer = false
        sync()
        blocking.updateShieldsForCurrentHabitState()
        ActivityLog.log("FREEZE_ACCEPTED")
    }

    func declineFreeze() {
        store.declineFreeze()
        pendingFreezeOffer = false
        sync()
        blocking.updateShieldsForCurrentHabitState()
        ActivityLog.log("FREEZE_DECLINED")
    }

    func completeTask(_ task: TodayTask) {
        guard !completedTasks.contains(where: { $0.id == task.id }) else { return }
        guard task.location == nil else {
            // Location task — verify asynchronously
            _Concurrency.Task { [weak self] in
                await self?.completeTaskWithLocationCheck(task)
            }
            return
        }
        markComplete(task)
    }

    /// Async entry point for location-verified completion. Also callable directly from tests.
    @MainActor
    func completeTaskWithLocationCheck(_ task: TodayTask) async {
        guard task.location != nil else { markComplete(task); return }

        // Check if already visited today via background monitoring
        if store.hasVisitedLocation(taskID: task.id, on: Date().dateString) {
            locationVerificationFailed = nil
            markComplete(task)
            // One-time prompt to upgrade to Always authorization for background geofencing
            if locationVerifier.authorizationStatus == .authorizedWhenInUse && !store.hasPromptedLocationAlways {
                store.hasPromptedLocationAlways = true
                showLocationUpgradePrompt = true
            }
            return
        }

        // Show error state immediately so feedback is instant, regardless of GPS latency
        locationVerificationFailed = task.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            if self?.locationVerificationFailed == task.id {
                self?.locationVerificationFailed = nil
            }
        }

        // Not visited — try current location
        let verified = await locationVerifier.verifyCurrentLocation(for: task)
        if verified {
            locationVerificationFailed = nil
            markComplete(task)
            // One-time prompt to upgrade to Always authorization for background geofencing
            if locationVerifier.authorizationStatus == .authorizedWhenInUse && !store.hasPromptedLocationAlways {
                store.hasPromptedLocationAlways = true
                showLocationUpgradePrompt = true
            }
        }
    }

    private func markComplete(_ task: TodayTask) {
        // Clear any pending undo from a previous completion
        clearUndo()

        let prevStreak = store.streakData.currentStreak
        // Log on the task's original scheduled date (past date for carryovers).
        store.completeTask(task.id, on: task.scheduledDateString)
        store.updateStreak(for: Date().dateString)
        todayTasks.removeAll { $0.id == task.id }
        completedTasks.append(task)
        hasCompletedTaskToday = true
        blocking.updateShieldsForCurrentHabitState()
        SchedulingService.shared.rescheduleReminderIfNeeded()
        WidgetCenter.shared.reloadAllTimelines()
        sync()
        let newStreak = store.streakData.currentStreak
        let streakChanged = newStreak > prevStreak
        ActivityLog.log("TASK_COMPLETED: \"\(task.title)\"" + (streakChanged ? " → streak now \(newStreak)" : ""))
        if streakChanged {
            streakAnimationTrigger += 1
            ReviewManager.requestIfEligible(currentStreak: newStreak)
        }

        // Offer brief undo window
        undoTask = task
        undoTaskID = task.id
        showUndoToast = true
        undoTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.clearUndo()
            }
        }
    }

    func undoLastCompletion() {
        guard let task = undoTask else { return }
        store.uncompleteTask(task.id, on: task.scheduledDateString)
        completedTasks.removeAll { $0.id == task.id }
        blocking.updateShieldsForCurrentHabitState()
        WidgetCenter.shared.reloadAllTimelines()
        sync()
        ActivityLog.log("TASK_UNDO: \"\(task.title)\"")
        clearUndo()
    }

    private func clearUndo() {
        undoTimer?.invalidate()
        undoTimer = nil
        undoTask = nil
        undoTaskID = nil
        showUndoToast = false
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
            guard task.location == nil else { return false } // combined tasks need manual tap for location check
            return stepsToday >= target
        }
        for task in toComplete {
            completeTask(task)
        }
    }

    // MARK: - Private

    private func sync() {
        locationAlwaysAuthorized = locationVerifier.authorizationStatus == .authorizedAlways
        let all = store.buildTodayTasks()
        // Carryovers first, then today's scheduled tasks
        todayTasks = all.sorted { a, b in
            if a.isCarryOver && !b.isCarryOver { return true }
            return false
        }

        // Rebuild completed tasks from store so they survive app reopen
        let completedIDs = store.completionLog[Date().dateString] ?? []
        completedTasks = store.tasks
            .filter { completedIDs.contains($0.id) }
            .map { task in
                TodayTask(
                    id: task.id,
                    title: task.title,
                    blocksApps: task.blocksApps,
                    isCarryOver: false,
                    originalDay: nil,
                    scheduledDateString: Date().dateString,
                    isOnce: task.isOnce,
                    stepTarget: task.stepTarget,
                    location: task.location
                )
            }

        streak = store.streakData.currentStreak
        hasCompletedTaskToday = !completedIDs.isEmpty
    }
}
