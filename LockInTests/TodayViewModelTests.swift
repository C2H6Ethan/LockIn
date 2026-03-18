import XCTest
@testable import LockIn

// Note: MockShieldApplier is defined in BlockingServiceTests.swift (same test module)

final class TodayViewModelTests: XCTestCase {

    var store: SharedStore!
    var mockApplier: MockShieldApplier!
    var blocking: BlockingService!
    var sut: TodayViewModel!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.today.\(UUID().uuidString)")
        mockApplier = MockShieldApplier()
        blocking = BlockingService(store: store, applier: mockApplier)
        sut = TodayViewModel(store: store, blocking: blocking)
    }

    override func tearDown() {
        sut = nil
        blocking = nil
        mockApplier = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialState_todayTasksEmpty() {
        XCTAssertTrue(sut.todayTasks.isEmpty)
    }

    func testInitialState_streakZero() {
        XCTAssertEqual(sut.streak, 0)
    }

    func testInitialState_showingAddTaskFalse() {
        XCTAssertFalse(sut.showingAddTask)
    }

    func testInitialState_allBlockingDoneTrue_whenNoTasks() {
        XCTAssertTrue(sut.allBlockingDone)
    }

    // MARK: - onAppear / sync

    func testOnAppear_loadsTasksScheduledForToday() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()
        XCTAssertEqual(sut.todayTasks.count, 1)
        XCTAssertEqual(sut.todayTasks[0].title, "Run")
    }

    func testOnAppear_excludesCompletedTodayTasks() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(task)
        store.completeTask(task.id, on: Date().dateString)
        sut.onAppear()
        XCTAssertTrue(sut.todayTasks.isEmpty)
    }

    func testOnAppear_loadsStreakFromStore() {
        store.streakData = StreakData(currentStreak: 7, longestStreak: 10)
        sut.onAppear()
        XCTAssertEqual(sut.streak, 7)
    }

    func testOnAppear_nonBlockingTaskNotScheduledToday_excluded() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let otherWeekday = todayWeekday == 1 ? 2 : 1
        // Non-blocking task on another day: doesn't carry over
        store.addTask(Task(title: "Floss", activeDays: [otherWeekday], blocksApps: false))
        sut.onAppear()
        XCTAssertTrue(sut.todayTasks.isEmpty)
    }

    func testOnAppear_includesNonBlockingTaskScheduledToday() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Floss", activeDays: [todayWeekday], blocksApps: false))
        sut.onAppear()
        XCTAssertEqual(sut.todayTasks.count, 1)
        XCTAssertFalse(sut.todayTasks[0].blocksApps)
    }

    func testOnAppear_carryoversListedFirst() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yWeekday != todayWeekday else { return }

        let todayTask = Task(title: "Today Task", activeDays: [todayWeekday], blocksApps: false)
        // createdAt = yesterday so it's eligible as a carryover
        let carryoverTask = Task(title: "Carryover Task", activeDays: [yWeekday], blocksApps: true, createdAt: yesterday)
        store.addTask(todayTask)
        store.addTask(carryoverTask)
        sut.onAppear()

        XCTAssertEqual(sut.todayTasks.count, 2)
        XCTAssertTrue(sut.todayTasks[0].isCarryOver, "Carryover should be first")
        XCTAssertFalse(sut.todayTasks[1].isCarryOver, "Today's task should be second")
    }

    func testOnAppear_calledMultipleTimes_doesNotDuplicate() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()
        sut.onAppear()
        XCTAssertEqual(sut.todayTasks.count, 1)
    }

    // MARK: - allBlockingDone

    func testAllBlockingDone_false_whenBlockingTaskExists() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday], blocksApps: true))
        sut.onAppear()
        XCTAssertFalse(sut.allBlockingDone)
    }

    func testAllBlockingDone_true_whenOnlyNonBlockingTasksExist() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Floss", activeDays: [todayWeekday], blocksApps: false))
        sut.onAppear()
        XCTAssertTrue(sut.allBlockingDone)
    }

    func testAllBlockingDone_true_whenNoTasks() {
        sut.onAppear()
        XCTAssertTrue(sut.allBlockingDone)
    }

    // MARK: - completeTask

    func testCompleteTask_removesTaskFromList() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()
        XCTAssertEqual(sut.todayTasks.count, 1)

        sut.completeTask(sut.todayTasks[0])

        XCTAssertTrue(sut.todayTasks.isEmpty)
    }

    func testCompleteTask_logsCompletionInStore() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(task)
        sut.onAppear()

        sut.completeTask(sut.todayTasks[0])

        XCTAssertTrue(store.completionLog[Date().dateString]?.contains(task.id) ?? false)
    }

    func testCompleteTask_triggersShieldUpdate() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()

        sut.completeTask(sut.todayTasks[0])

        // Shield update was triggered (remove is called since no apps selected)
        XCTAssertGreaterThan(mockApplier.removeCallCount, 0)
    }

    func testCompleteTask_allBlockingDoneAfterLastBlockingTask() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday], blocksApps: true))
        sut.onAppear()
        XCTAssertFalse(sut.allBlockingDone)

        sut.completeTask(sut.todayTasks[0])

        XCTAssertTrue(sut.allBlockingDone)
    }

    func testCompleteTask_onlyRemovesMatchingTask() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        store.addTask(Task(title: "Meditate", activeDays: [todayWeekday]))
        sut.onAppear()
        XCTAssertEqual(sut.todayTasks.count, 2)

        let run = sut.todayTasks.first(where: { $0.title == "Run" })!
        sut.completeTask(run)

        XCTAssertEqual(sut.todayTasks.count, 1)
        XCTAssertEqual(sut.todayTasks[0].title, "Meditate")
    }

    func testCompleteTask_nonBlockingTask_doesNotChangeAllBlockingDone() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday], blocksApps: true))
        store.addTask(Task(title: "Floss", activeDays: [todayWeekday], blocksApps: false))
        sut.onAppear()

        let floss = sut.todayTasks.first(where: { $0.title == "Floss" })!
        sut.completeTask(floss)

        // Run (blocking) still remains → not done
        XCTAssertFalse(sut.allBlockingDone)
        XCTAssertEqual(sut.todayTasks.count, 1)
    }

    // MARK: - Notification refresh

    // MARK: - Carryover completion

    func testCompleteCarryoverTask_logsOnOriginalDate() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yWeekday != todayWeekday else { return }

        let task = Task(title: "Run", activeDays: [yWeekday], blocksApps: true, createdAt: yesterday)
        store.addTask(task)
        sut.onAppear()
        XCTAssertEqual(sut.todayTasks.count, 1)
        XCTAssertTrue(sut.todayTasks[0].isCarryOver)

        sut.completeTask(sut.todayTasks[0])

        // Must be logged on the ORIGINAL date, not today
        XCTAssertTrue(store.completionLog[yesterday.dateString]?.contains(task.id) ?? false,
                      "Carryover must log completion on its original scheduled date")
        XCTAssertFalse(store.completionLog[Date().dateString]?.contains(task.id) ?? false,
                       "Carryover must NOT log on today's date")
    }

    func testCompleteCarryoverTask_removedAndDoesNotReappear() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yWeekday != todayWeekday else { return }

        let task = Task(title: "Run", activeDays: [yWeekday], blocksApps: true, createdAt: yesterday)
        store.addTask(task)
        sut.onAppear()
        XCTAssertEqual(sut.todayTasks.count, 1)

        sut.completeTask(sut.todayTasks[0])

        XCTAssertTrue(sut.todayTasks.isEmpty, "Completed carryover must not reappear")
    }

    func testNewTaskForPastWeekday_doesNotAppearAsCarryover() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yWeekday != todayWeekday else { return }

        // Task created NOW with yesterday's weekday — should NOT appear as carryover
        let task = Task(title: "Run", activeDays: [yWeekday], blocksApps: true) // createdAt = Date()
        store.addTask(task)
        sut.onAppear()
        XCTAssertTrue(sut.todayTasks.isEmpty)
    }

    // MARK: - addTask streak decrement

    func testAddWeeklyTask_forToday_decrementsStreak() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        // Seed a streak of 1 completed today
        let existingTask = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(existingTask)
        store.completeTask(existingTask.id, on: Date().dateString)
        store.updateStreak(for: Date().dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Add a new weekly task for today — streak should drop back to 0
        sut.addTask(title: "Floss", recurrence: .weekly(days: [todayWeekday]), blocksApps: false)

        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testAddOnceTask_startingToday_decrementsStreak() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        // Seed a streak of 1 completed today
        let existingTask = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(existingTask)
        store.completeTask(existingTask.id, on: Date().dateString)
        store.updateStreak(for: Date().dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Add a once task starting today — streak must drop
        sut.addTask(title: "Doctor", recurrence: .once(startDate: Date().dateString), blocksApps: false)

        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testAddOnceTask_startingTomorrow_doesNotDecrementStreak() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let existingTask = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(existingTask)
        store.completeTask(existingTask.id, on: Date().dateString)
        store.updateStreak(for: Date().dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        sut.addTask(title: "Doctor", recurrence: .once(startDate: tomorrow.dateString), blocksApps: false)

        XCTAssertEqual(store.streakData.currentStreak, 1)
    }

    func testAddOnceTask_noStreakToday_noChange() {
        // Streak was not set today — adding once task should not crash or corrupt data
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: nil)
        sut.addTask(title: "Doctor", recurrence: .once(startDate: Date().dateString), blocksApps: false)
        XCTAssertEqual(store.streakData.currentStreak, 3)
    }

    // MARK: - completedTasks

    func testInitialState_completedTasksEmpty() {
        XCTAssertTrue(sut.completedTasks.isEmpty)
    }

    func testCompleteTask_appearsInCompletedTasks() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()

        sut.completeTask(sut.todayTasks[0])

        XCTAssertEqual(sut.completedTasks.count, 1)
        XCTAssertEqual(sut.completedTasks[0].title, "Run")
    }

    func testCompleteTask_multipleCompleted_allInCompletedTasks() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        store.addTask(Task(title: "Meditate", activeDays: [todayWeekday]))
        sut.onAppear()

        sut.completeTask(sut.todayTasks.first(where: { $0.title == "Run" })!)
        sut.completeTask(sut.todayTasks.first(where: { $0.title == "Meditate" })!)

        XCTAssertEqual(sut.completedTasks.count, 2)
    }

    func testCompleteTask_completedTaskStillRemovedFromTodayTasks() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()

        sut.completeTask(sut.todayTasks[0])

        XCTAssertTrue(sut.todayTasks.isEmpty)
        XCTAssertEqual(sut.completedTasks.count, 1)
    }

    func testSync_rebuildsCompletedTasksFromStore_afterReopen() {
        // Simulate completing a task in a previous session by writing directly to store
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(task)
        store.completeTask(task.id, on: Date().dateString)

        // Fresh viewModel (simulates app reopen)
        let freshVM = TodayViewModel(store: store, blocking: blocking)
        freshVM.onAppear()

        XCTAssertEqual(freshVM.completedTasks.count, 1)
        XCTAssertEqual(freshVM.completedTasks[0].title, "Run")
    }

    func testCompleteTask_preservesCompletedOrder() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        store.addTask(Task(title: "Meditate", activeDays: [todayWeekday]))
        store.addTask(Task(title: "Read", activeDays: [todayWeekday]))
        sut.onAppear()

        let run = sut.todayTasks.first(where: { $0.title == "Run" })!
        let meditate = sut.todayTasks.first(where: { $0.title == "Meditate" })!
        sut.completeTask(run)
        sut.completeTask(meditate)

        XCTAssertEqual(sut.completedTasks[0].title, "Run")
        XCTAssertEqual(sut.completedTasks[1].title, "Meditate")
        XCTAssertEqual(sut.todayTasks.count, 1)
        XCTAssertEqual(sut.todayTasks[0].title, "Read")
    }

    // MARK: - undoLastCompletion

    func testUndoLastCompletion_reversesCompletion() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()
        sut.completeTask(sut.todayTasks[0])
        XCTAssertTrue(sut.showUndoToast)
        XCTAssertEqual(sut.completedTasks.count, 1)

        sut.undoLastCompletion()

        XCTAssertTrue(sut.completedTasks.isEmpty)
        XCTAssertEqual(sut.todayTasks.count, 1)
        XCTAssertEqual(sut.todayTasks[0].title, "Run")
        XCTAssertFalse(sut.showUndoToast)
    }

    func testUndoLastCompletion_removesFromCompletionLog() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(task)
        sut.onAppear()
        sut.completeTask(sut.todayTasks[0])
        XCTAssertTrue(store.completionLog[Date().dateString]?.contains(task.id) ?? false)

        sut.undoLastCompletion()

        XCTAssertFalse(store.completionLog[Date().dateString]?.contains(task.id) ?? false)
    }

    func testUndoLastCompletion_triggersShieldUpdate() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday], blocksApps: true))
        sut.onAppear()
        sut.completeTask(sut.todayTasks[0])
        let callsBefore = mockApplier.removeCallCount + mockApplier.applyCallCount

        sut.undoLastCompletion()

        XCTAssertGreaterThan(mockApplier.removeCallCount + mockApplier.applyCallCount, callsBefore)
    }

    func testUndoLastCompletion_blockingTask_allBlockingDoneBecomeFalse() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday], blocksApps: true))
        sut.onAppear()
        sut.completeTask(sut.todayTasks[0])
        XCTAssertTrue(sut.allBlockingDone)

        sut.undoLastCompletion()

        XCTAssertFalse(sut.allBlockingDone)
    }

    func testCompleteSecondTask_clearsPreviousUndo() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        store.addTask(Task(title: "Meditate", activeDays: [todayWeekday]))
        sut.onAppear()

        sut.completeTask(sut.todayTasks.first(where: { $0.title == "Run" })!)
        sut.completeTask(sut.todayTasks.first(where: { $0.title == "Meditate" })!)

        // Undo should only affect the last completed task (Meditate)
        sut.undoLastCompletion()

        XCTAssertEqual(sut.completedTasks.count, 1)
        XCTAssertEqual(sut.completedTasks[0].title, "Run")
        XCTAssertEqual(sut.todayTasks.count, 1)
        XCTAssertEqual(sut.todayTasks[0].title, "Meditate")
    }

    func testUndoLastCompletion_noOp_whenNothingToUndo() {
        sut.onAppear()
        sut.undoLastCompletion()
        // Should not crash
        XCTAssertTrue(sut.todayTasks.isEmpty)
    }

    func testCompleteTask_showsUndoToast() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()

        sut.completeTask(sut.todayTasks[0])

        XCTAssertTrue(sut.showUndoToast)
    }

    func testUndoThenReComplete_worksCorrectly() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        sut.onAppear()

        sut.completeTask(sut.todayTasks[0])
        sut.undoLastCompletion()
        XCTAssertEqual(sut.todayTasks.count, 1)

        sut.completeTask(sut.todayTasks[0])
        XCTAssertTrue(sut.todayTasks.isEmpty)
        XCTAssertEqual(sut.completedTasks.count, 1)
    }

    // MARK: - Notification refresh

    func testHabitsDidChange_notification_reloadsTasks() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        sut.onAppear()
        XCTAssertTrue(sut.todayTasks.isEmpty)

        // Add a task externally and fire notification
        store.addTask(Task(title: "New Task", activeDays: [todayWeekday]))
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)

        // Give notification a moment to be processed synchronously (it's dispatched on .main)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))

        XCTAssertEqual(sut.todayTasks.count, 1)
    }
}
