import XCTest
import FamilyControls
@testable import LockIn

/// Tests that verify shield state is correct across day boundaries.
/// The core bug: shields were only refreshed on app foreground or weekly interval start,
/// so a user who completed all tasks yesterday could access blocked apps the next morning
/// until they opened the app.
final class DayTransitionTests: XCTestCase {

    var store: SharedStore!
    var mockApplier: MockShieldApplier!
    var sut: BlockingService!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.daytransition.\(UUID().uuidString)")
        mockApplier = MockShieldApplier()
        sut = BlockingService(store: store, applier: mockApplier)
    }

    override func tearDown() {
        sut = nil
        mockApplier = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var todayWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }

    private var yesterdayWeekday: Int {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return Calendar.current.component(.weekday, from: yesterday)
    }

    private var yesterdayString: String {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!.dateString
    }

    // MARK: - Day transition: incomplete tasks on new day require shields

    func testNewDay_incompleteTasks_shieldsApplied() {
        // Task scheduled for today, not completed
        let task = Task(title: "Gym", activeDays: [todayWeekday])
        store.addTask(task)

        // Calling updateShields (as the daily monitor does at midnight) should apply shields
        // We can't test with real FamilyActivitySelection tokens in unit tests,
        // but we CAN verify the logic: incomplete blocking tasks exist
        let incomplete = store.incompleteBlockingTasks
        XCTAssertEqual(incomplete.count, 1)
        XCTAssertEqual(incomplete.first?.title, "Gym")
    }

    func testNewDay_allTasksCompleteYesterday_todayTasksIncomplete() {
        // Yesterday's task — completed
        let yesterdayTask = Task(title: "Read", activeDays: [yesterdayWeekday])
        store.addTask(yesterdayTask)
        store.completeTask(yesterdayTask.id, on: yesterdayString)

        // Today's task — not completed
        let todayTask = Task(title: "Gym", activeDays: [todayWeekday])
        store.addTask(todayTask)

        // Yesterday is done, but today is not — shields should be needed
        let incomplete = store.incompleteBlockingTasks
        XCTAssertEqual(incomplete.count, 1)
        XCTAssertEqual(incomplete.first?.id, todayTask.id)
    }

    func testNewDay_allTasksComplete_noShieldsNeeded() {
        let task = Task(title: "Gym", activeDays: [todayWeekday])
        store.addTask(task)
        store.completeTask(task.id, on: Date().dateString)

        let incomplete = store.incompleteBlockingTasks
        XCTAssertTrue(incomplete.isEmpty)
    }

    func testNewDay_noTasksScheduled_noShieldsNeeded() {
        // Task only on yesterday, not today
        let task = Task(title: "Read", activeDays: [yesterdayWeekday])
        // Only add if yesterday != today (different weekday)
        guard yesterdayWeekday != todayWeekday else { return }
        store.addTask(task)
        store.completeTask(task.id, on: yesterdayString)

        let incomplete = store.incompleteBlockingTasks
        XCTAssertTrue(incomplete.isEmpty)
    }

    // MARK: - BlockingService correctly reflects day transition

    func testUpdateShields_newDayIncompleteTasks_removesShields_whenNoAppsSelected() {
        // Incomplete task exists but no apps are selected → remove (can't shield nothing)
        let task = Task(title: "Gym", activeDays: [todayWeekday])
        store.addTask(task)

        sut.updateShieldsForCurrentHabitState()

        // No apps selected = remove
        XCTAssertEqual(mockApplier.removeCallCount, 1)
        XCTAssertEqual(mockApplier.applyCallCount, 0)
    }

    func testUpdateShields_completedYesterday_incompleteTodaySameTask_needsShields() {
        // A task that repeats on both yesterday and today
        // Completed yesterday but NOT today — should need shields today
        let task = Task(title: "Daily Gym", activeDays: [yesterdayWeekday, todayWeekday])
        store.addTask(task)
        store.completeTask(task.id, on: yesterdayString)

        // Today it should still be incomplete
        let incomplete = store.incompleteBlockingTasks
        XCTAssertEqual(incomplete.count, 1, "Task completed yesterday should still be incomplete today")
    }

    // MARK: - Carryover tasks across day boundary

    func testCarryover_incompleteYesterdayTask_appearsToday() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let task = Task(title: "Missed Task", activeDays: [yesterdayWeekday], createdAt: twoDaysAgo)
        store.addTask(task)
        // Not completed yesterday → should carry over to today

        let todayTasks = store.buildTodayTasks()
        let carryover = todayTasks.first { $0.id == task.id }

        XCTAssertNotNil(carryover, "Incomplete task from yesterday should carry over")
        XCTAssertTrue(carryover?.isCarryOver ?? false)
    }

    func testCarryover_incompleteBlockingTask_blocksToday() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let task = Task(title: "Missed Blocking Task", activeDays: [yesterdayWeekday], blocksApps: true, createdAt: twoDaysAgo)
        store.addTask(task)
        // Not completed → carries over and still blocks

        let incomplete = store.incompleteBlockingTasks
        XCTAssertEqual(incomplete.count, 1)
        XCTAssertEqual(incomplete.first?.id, task.id)
    }

    // MARK: - Temporary unblock window across day boundary

    func testUnblockWindow_activeAtMidnight_stillRespected() {
        // Unblock window set to expire in 30 min (simulating it was set before midnight)
        store.unblockExpiresAt = Date().addingTimeInterval(30 * 60)
        let task = Task(title: "Gym", activeDays: [todayWeekday])
        store.addTask(task)

        sut.updateShieldsForCurrentHabitState()

        // Should no-op because unblock window is active
        XCTAssertEqual(mockApplier.applyCallCount, 0)
        XCTAssertEqual(mockApplier.removeCallCount, 0)
    }

    func testUnblockWindow_expiredAtMidnight_shieldsReapplied() {
        // Unblock window expired (set in the past)
        store.unblockExpiresAt = Date().addingTimeInterval(-60)
        let task = Task(title: "Gym", activeDays: [todayWeekday])
        store.addTask(task)

        sut.updateShieldsForCurrentHabitState()

        // Expired → should clear expiry and evaluate shields
        XCTAssertNil(store.unblockExpiresAt)
        // No apps selected so it removes, but the point is it didn't no-op
        XCTAssertEqual(mockApplier.removeCallCount, 1)
    }

    // MARK: - Non-blocking tasks don't trigger shields

    func testNonBlockingTask_incomplete_noShieldsNeeded() {
        let task = Task(title: "Floss", activeDays: [todayWeekday], blocksApps: false)
        store.addTask(task)

        let incomplete = store.incompleteBlockingTasks
        XCTAssertTrue(incomplete.isEmpty, "Non-blocking tasks should not appear in incompleteBlockingTasks")
    }

    // MARK: - Multiple tasks across day boundary

    func testMixedCompletion_onlyIncompleteBlockingTasksCount() {
        let completed = Task(title: "Done", activeDays: [todayWeekday])
        let incomplete = Task(title: "Not Done", activeDays: [todayWeekday])
        let nonBlocking = Task(title: "Optional", activeDays: [todayWeekday], blocksApps: false)

        store.addTask(completed)
        store.addTask(incomplete)
        store.addTask(nonBlocking)
        store.completeTask(completed.id, on: Date().dateString)

        let blocking = store.incompleteBlockingTasks
        XCTAssertEqual(blocking.count, 1)
        XCTAssertEqual(blocking.first?.id, incomplete.id)
    }
}
