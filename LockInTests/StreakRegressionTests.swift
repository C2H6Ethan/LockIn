import XCTest
@testable import LockIn

/// Regression tests for every streak bug fixed in this codebase.
/// Each test documents the root cause, the fix, and the invariant it guards.
final class StreakRegressionTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.regression.\(UUID().uuidString)")
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    // MARK: - Bug: tasks created today appeared as missed on previous days
    // Root cause: checkAndUpdateStreak's weekly-task scan used `tasks.filter { $0.activeDays.contains(weekday) }`
    // with no createdAt guard. A task created today matched yesterday's weekday check → false miss.
    // Fix: added `Calendar.current.startOfDay(for: $0.createdAt) <= dayStart` to the filter.

    func testCreatedAtFilter_taskCreatedToday_notCountedAsMissedYesterday() {
        let yesterday = date(2026, 3, 24) // weekday 3 (Tuesday)
        let today     = date(2026, 3, 25) // weekday 4 (Wednesday)
        let weekdayYesterday = Calendar.current.component(.weekday, from: yesterday)

        store.streakData = StreakData(currentStreak: 5, longestStreak: 5,
                                      lastCompletedDate: yesterday.dateString)
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = today.isoWeekString

        // Task created TODAY but scheduled for yesterday's weekday (e.g. a Tuesday task created Wednesday).
        let task = Task(title: "gym", recurrence: .weekly(days: [weekdayYesterday]),
                        blocksApps: true, createdAt: today)
        store.addTask(task)

        store.checkAndUpdateStreak(today: today)

        XCTAssertEqual(store.streakData.currentStreak, 5,
                       "Task created today must not be counted as missed on previous days")
        XCTAssertFalse(store.pendingFreezeOffer,
                       "No freeze should be offered when the only 'missed' task didn't exist yet")
    }

    func testCreatedAtFilter_taskCreatedTodayScheduledEveryDay_noMissForPastWeek() {
        // App reinstalled → all tasks created today. 7-day scan should find zero missed days.
        let lastCompleted = date(2026, 3, 18) // week ago
        let today         = date(2026, 3, 25)

        store.streakData = StreakData(currentStreak: 10, longestStreak: 10,
                                      lastCompletedDate: lastCompleted.dateString)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString

        // All tasks created today — were not active last week
        for weekday in 1...7 {
            let t = Task(title: "daily", recurrence: .weekly(days: [weekday]),
                         blocksApps: true, createdAt: today)
            store.addTask(t)
        }

        store.checkAndUpdateStreak(today: today)

        XCTAssertEqual(store.streakData.currentStreak, 10,
                       "Tasks created today must not generate missed days for the past scan range")
    }

    // MARK: - Bug: consumeFreeze + subsequent task edit nuked the streak
    // Root cause: consumeFreeze patches lastCompletedDate to yesterday (tasks NOT actually done).
    // Any subsequent task edit triggered reconcileStreakAfterEdit, which saw incomplete tasks on
    // lastCompletedDate and rolled back the streak. With freeze count now 0, checkAndUpdateStreak
    // then found that same missed day and reset streak to 0.
    // Fix: consumeFreeze stores frozenDate; reconcileStreakAfterEdit skips rollback on frozenDate.

    func testFrozenDate_taskEditAfterFreeze_doesNotRollBackStreak() {
        let yesterday        = date(2026, 3, 24)
        let today            = date(2026, 3, 25)
        let yesterdayWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday     = Calendar.current.component(.weekday, from: today)

        // Tasks exist on both days but were NOT completed on yesterday (freeze day)
        let task = Task(title: "gym",
                        recurrence: .weekly(days: [yesterdayWeekday, todayWeekday]),
                        blocksApps: true, createdAt: yesterday)
        store.addTask(task)

        store.streakData = StreakData(currentStreak: 5, longestStreak: 5,
                                      lastCompletedDate: date(2026, 3, 23).dateString)
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = today.isoWeekString

        // Simulate freeze offered and accepted
        store.pendingFreezeOffer = true
        store.consumeFreeze(today: today)

        XCTAssertEqual(store.streakData.currentStreak, 5)
        XCTAssertEqual(store.streakData.lastCompletedDate, yesterday.dateString)

        // Now edit the task (e.g. user adds a start time)
        let updated = Task(id: task.id, title: task.title, recurrence: task.recurrence,
                           blocksApps: true, createdAt: task.createdAt,
                           blockingStartTime: DateComponents(hour: 9, minute: 0))
        store.updateTask(updated)

        XCTAssertEqual(store.streakData.currentStreak, 5,
                       "Editing a task after consuming a freeze must not roll back the streak")
    }

    func testFrozenDate_multipleEditsAfterFreeze_streakStaysIntact() {
        let yesterday        = date(2026, 3, 24)
        let yesterdayWeekday = Calendar.current.component(.weekday, from: yesterday)

        let task = Task(title: "gym", recurrence: .weekly(days: [yesterdayWeekday]),
                        blocksApps: true, createdAt: yesterday)
        store.addTask(task)

        store.streakData = StreakData(currentStreak: 3, longestStreak: 3,
                                      lastCompletedDate: date(2026, 3, 23).dateString)
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = date(2026, 3, 25).isoWeekString

        store.consumeFreeze()
        XCTAssertEqual(store.streakData.currentStreak, 3)

        // Edit three times
        for i in 1...3 {
            let updated = Task(id: task.id, title: "gym v\(i)", recurrence: task.recurrence,
                               blocksApps: true, createdAt: task.createdAt)
            store.updateTask(updated)
        }

        XCTAssertEqual(store.streakData.currentStreak, 3,
                       "Repeated edits after freeze must not progressively decrement the streak")
    }

    // MARK: - Multiple missed days must NOT offer freeze — only exactly 1 missed day triggers offer

    func testCheckAndUpdateStreak_twoMissedDays_freezeAvailable_noOffer_resetsToZero() {
        let today    = date(2026, 3, 25)
        let last     = date(2026, 3, 22) // last completed — 3 days ago

        store.streakData = StreakData(currentStreak: 5, longestStreak: 5,
                                      lastCompletedDate: last.dateString)
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = today.isoWeekString

        // Tasks on both missed days (Mon=23, Tue=24), neither completed
        let mon = Task(title: "A", recurrence: .weekly(days: [2]), blocksApps: true, createdAt: last) // Mon 23
        let tue = Task(title: "B", recurrence: .weekly(days: [3]), blocksApps: true, createdAt: last) // Tue 24
        store.addTask(mon)
        store.addTask(tue)

        store.checkAndUpdateStreak(today: today)

        XCTAssertFalse(store.pendingFreezeOffer,
                       "Freeze must only be offered for exactly 1 missed day — not 2")
        XCTAssertEqual(store.streakData.currentStreak, 0,
                       "Two missed days must reset streak even if freeze is available")
    }

    func testCheckAndUpdateStreak_oneMissedDay_freezeAvailable_offersFreeze_doesNotReset() {
        // Control: exactly 1 missed day + freeze available → offer, NOT reset.
        let today     = date(2026, 3, 25)
        let yesterday = date(2026, 3, 24)
        let last      = date(2026, 3, 23)

        store.streakData = StreakData(currentStreak: 5, longestStreak: 5,
                                      lastCompletedDate: last.dateString)
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = today.isoWeekString

        // One task on yesterday (Tuesday), not completed
        let task = Task(title: "gym", recurrence: .weekly(days: [3]), blocksApps: true, createdAt: last)
        store.addTask(task)
        _ = yesterday

        store.checkAndUpdateStreak(today: today)

        XCTAssertTrue(store.pendingFreezeOffer)
        XCTAssertEqual(store.streakData.currentStreak, 5, "Freeze offer must hold the streak")
    }

    // MARK: - checkAndUpdateStreak is idempotent

    func testCheckAndUpdateStreak_calledTwiceSameDay_idempotent() {
        let today     = date(2026, 3, 25)
        let yesterday = date(2026, 3, 24)

        store.streakData = StreakData(currentStreak: 3, longestStreak: 3,
                                      lastCompletedDate: yesterday.dateString)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString

        // No missed days
        store.checkAndUpdateStreak(today: today)
        store.checkAndUpdateStreak(today: today)

        XCTAssertEqual(store.streakData.currentStreak, 3)
        XCTAssertFalse(store.pendingFreezeOffer)
    }

    // MARK: - deleteTask: no restore when other tasks are still incomplete

    func testDeleteTask_incompleteRemainingTasks_streakNotRestored() {
        let today        = date(2026, 3, 25)
        let todayWeekday = Calendar.current.component(.weekday, from: today)
        let todayString  = today.dateString
        let yesterday    = date(2026, 3, 24)

        let task1 = Task(title: "gym",     recurrence: .weekly(days: [todayWeekday]),
                         blocksApps: true, createdAt: today)
        let task2 = Task(title: "leetcode", recurrence: .weekly(days: [todayWeekday]),
                         blocksApps: true, createdAt: today)
        store.addTask(task1)
        store.addTask(task2)

        store.streakData = StreakData(currentStreak: 5, longestStreak: 5,
                                      lastCompletedDate: yesterday.dateString)

        // Complete task1 only — task2 still incomplete
        store.completeTask(task1.id, on: todayString)

        // Delete task1 (the completed one). task2 is still pending.
        store.removeTask(id: task1.id)

        XCTAssertNotEqual(store.streakData.lastCompletedDate, todayString,
                          "Streak must not advance to today when task2 is still incomplete")
        XCTAssertEqual(store.streakData.currentStreak, 5)
    }

    func testDeleteTask_onlyIncompleteTask_streakNotRestored() {
        // Delete the only task for today while it's incomplete → today has no tasks → updateStreak
        // fires but completionLog is empty for today → guard fails → no advance.
        let today        = date(2026, 3, 25)
        let todayWeekday = Calendar.current.component(.weekday, from: today)
        let yesterday    = date(2026, 3, 24)

        let task = Task(title: "gym", recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true, createdAt: today)
        store.addTask(task)
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5,
                                      lastCompletedDate: yesterday.dateString)

        // Delete without completing
        store.removeTask(id: task.id)

        XCTAssertEqual(store.streakData.currentStreak, 5)
        XCTAssertEqual(store.streakData.lastCompletedDate, yesterday.dateString)
    }

    func testDeleteTask_nonTodayTask_noStreakEffect() {
        // Deleting a task scheduled for a different weekday has no streak side effect.
        let today        = date(2026, 3, 25) // Wednesday
        let todayWeekday = Calendar.current.component(.weekday, from: today)
        let otherWeekday = (todayWeekday % 7) + 1 // a different day

        let todayTask = Task(title: "gym", recurrence: .weekly(days: [todayWeekday]),
                             blocksApps: true, createdAt: today)
        let otherTask = Task(title: "yoga", recurrence: .weekly(days: [otherWeekday]),
                             blocksApps: true, createdAt: today)
        store.addTask(todayTask)
        store.addTask(otherTask)

        store.completeTask(todayTask.id, on: today.dateString)
        store.updateStreak(for: today.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        store.removeTask(id: otherTask.id, today: today)

        XCTAssertEqual(store.streakData.currentStreak, 1,
                       "Deleting a task on a different day must not affect the current streak")
    }
}
