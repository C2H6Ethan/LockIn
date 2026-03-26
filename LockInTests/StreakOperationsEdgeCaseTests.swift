import XCTest
@testable import LockIn

/// Edge cases for streak operations not covered by the main StreakTests suite:
/// - updateStreak with no tasks in system
/// - updateStreak gap with task-free days at the boundary
/// - longestStreak preservation on reset
/// - uncompleteTask streak rollback
/// - freeze week-reset boundary
final class StreakOperationsEdgeCaseTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.ops.\(UUID().uuidString)")
        store.streakFreezeCount = 0
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    // MARK: - updateStreak: no tasks in system → no advance

    func testUpdateStreak_noTasksInSystem_doesNotAdvance() {
        // With no tasks, buildTodayTasks returns empty. The guard `!tasks.isEmpty` fires.
        let today = date(2026, 3, 25)
        store.updateStreak(for: today.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 0)
        XCTAssertNil(store.streakData.lastCompletedDate)
    }

    func testUpdateStreak_tasksExistButNoneForToday_doesNotAdvance() {
        // Tasks exist but none are scheduled for today's weekday.
        let today        = date(2026, 3, 25) // Wednesday, weekday 4
        let otherWeekday = 6 // Friday — not today

        let task = Task(title: "friday", recurrence: .weekly(days: [otherWeekday]),
                        blocksApps: true, createdAt: today)
        store.addTask(task)

        store.updateStreak(for: today.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 0,
                       "No tasks scheduled for today must not advance streak")
    }

    // MARK: - updateStreak: gap with task-free boundary days

    func testUpdateStreak_gapStart_taskFreeDay_freePass() {
        // lastCompleted = Mon. Tue: no tasks. Wed: complete task.
        // Gap (Tue) is task-free → free pass → streak continues.
        let mon = date(2026, 3, 23) // weekday 2
        let wed = date(2026, 3, 25) // weekday 4

        let monTask = Task(title: "M", recurrence: .weekly(days: [2]), blocksApps: true, createdAt: mon)
        let wedTask = Task(title: "W", recurrence: .weekly(days: [4]), blocksApps: true, createdAt: mon)
        store.addTask(monTask)
        store.addTask(wedTask)

        store.completeTask(monTask.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        store.completeTask(wedTask.id, on: wed.dateString)
        store.updateStreak(for: wed.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 2,
                       "Task-free Tuesday gap must be a free pass — streak should reach 2")
    }

    func testUpdateStreak_gapContainsMissedTask_resetsToOne() {
        // lastCompleted = Mon. Tue: task exists but was NOT completed. Wed: complete task.
        // Gap (Tue) has a missed task → streak resets to 1.
        let mon = date(2026, 3, 23)
        let wed = date(2026, 3, 25)

        let monTask = Task(title: "M", recurrence: .weekly(days: [2]), blocksApps: true, createdAt: mon)
        let tueTask = Task(title: "T", recurrence: .weekly(days: [3]), blocksApps: true, createdAt: mon)
        let wedTask = Task(title: "W", recurrence: .weekly(days: [4]), blocksApps: true, createdAt: mon)
        store.addTask(monTask)
        store.addTask(tueTask)
        store.addTask(wedTask)

        store.completeTask(monTask.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Tuesday: tueTask NOT completed
        store.completeTask(wedTask.id, on: wed.dateString)
        store.updateStreak(for: wed.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1,
                       "Missed Tuesday task must break the chain — streak resets to 1 not 2")
    }

    // MARK: - longestStreak preserved after reset

    func testLongestStreak_preservedAfterReset() {
        let mon = date(2026, 3, 16)
        let tue = date(2026, 3, 17)
        let wed = date(2026, 3, 18)
        let thu = date(2026, 3, 19) // missed
        let fri = date(2026, 3, 20)

        let t1 = Task(title: "A", recurrence: .weekly(days: [2]), blocksApps: true, createdAt: mon)
        let t2 = Task(title: "B", recurrence: .weekly(days: [3]), blocksApps: true, createdAt: mon)
        let t3 = Task(title: "C", recurrence: .weekly(days: [4]), blocksApps: true, createdAt: mon)
        let t4 = Task(title: "D", recurrence: .weekly(days: [5]), blocksApps: true, createdAt: mon) // missed
        let t5 = Task(title: "E", recurrence: .weekly(days: [6]), blocksApps: true, createdAt: mon)
        store.addTask(t1); store.addTask(t2); store.addTask(t3); store.addTask(t4); store.addTask(t5)

        // Mon–Wed: streak = 3
        store.completeTask(t1.id, on: mon.dateString); store.updateStreak(for: mon.dateString)
        store.completeTask(t2.id, on: tue.dateString); store.updateStreak(for: tue.dateString)
        store.completeTask(t3.id, on: wed.dateString); store.updateStreak(for: wed.dateString)
        XCTAssertEqual(store.streakData.longestStreak, 3)

        // Thu: missed (reset via checkAndUpdateStreak)
        store.streakFreezeWeekString = fri.isoWeekString
        store.checkAndUpdateStreak(today: fri)
        XCTAssertEqual(store.streakData.currentStreak, 0)
        XCTAssertEqual(store.streakData.longestStreak, 3,
                       "longestStreak must not decrease after a streak break")
        _ = thu
    }

    // MARK: - Freeze week reset

    func testStreakFreeze_newISOWeek_resetsFreezeCountToOne() {
        let thisWeek = date(2026, 3, 25)
        let nextWeek = date(2026, 4, 1)

        // Set up: freeze already used this week
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = thisWeek.isoWeekString

        // Simulate a new week opening: checkAndUpdateStreak should reset count to 1
        store.streakData = StreakData(currentStreak: 1, longestStreak: 1,
                                      lastCompletedDate: thisWeek.dateString)
        store.checkAndUpdateStreak(today: nextWeek)

        XCTAssertEqual(store.streakFreezeCount, 1,
                       "Freeze count must reset to 1 at the start of each new ISO week")
    }

    func testStreakFreeze_sameISOWeek_doesNotResetCount() {
        let monday  = date(2026, 3, 23)
        let tuesday = date(2026, 3, 24)

        store.streakFreezeCount = 0
        store.streakFreezeWeekString = monday.isoWeekString

        store.streakData = StreakData(currentStreak: 1, longestStreak: 1,
                                      lastCompletedDate: monday.dateString)
        store.checkAndUpdateStreak(today: tuesday)

        XCTAssertEqual(store.streakFreezeCount, 0,
                       "Freeze count must not reset mid-week")
    }

    // MARK: - declineFreeze: resets streak, preserves longestStreak

    func testDeclineFreeze_resetsCurrentStreak_preservesLongest() {
        store.streakData = StreakData(currentStreak: 7, longestStreak: 15, lastCompletedDate: nil)
        store.pendingFreezeOffer = true

        store.declineFreeze()

        XCTAssertEqual(store.streakData.currentStreak, 0)
        XCTAssertEqual(store.streakData.longestStreak, 15,
                       "longestStreak must survive a freeze decline")
        XCTAssertFalse(store.pendingFreezeOffer)
    }

    // MARK: - consumeFreeze: preserves currentStreak, decrements freeze count

    func testConsumeFreeze_preservesStreakAndDecrementsCount() {
        store.streakData = StreakData(currentStreak: 5, longestStreak: 10, lastCompletedDate: nil)
        store.streakFreezeCount = 1

        store.consumeFreeze()

        XCTAssertEqual(store.streakData.currentStreak, 5,
                       "consumeFreeze must not change currentStreak")
        XCTAssertEqual(store.streakFreezeCount, 0,
                       "consumeFreeze must decrement freeze count")
        XCTAssertFalse(store.pendingFreezeOffer)
    }

    func testConsumeFreeze_setsFrozenDateToYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.streakFreezeCount = 1
        store.consumeFreeze()
        XCTAssertEqual(store.streakData.lastCompletedDate, yesterday.dateString,
                       "consumeFreeze must patch lastCompletedDate to yesterday")
    }

    // MARK: - checkAndUpdateStreak: streak = 0 → no-op (no freeze offered, no change)

    func testCheckAndUpdateStreak_streakZero_noFreezeOffer() {
        let today     = date(2026, 3, 25)
        let yesterday = date(2026, 3, 24)

        store.streakData = StreakData(currentStreak: 0, longestStreak: 10,
                                      lastCompletedDate: yesterday.dateString)
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = today.isoWeekString

        // Add a task for yesterday (would be "missed")
        let task = Task(title: "gym", recurrence: .weekly(days: [3]), blocksApps: true, createdAt: yesterday)
        store.addTask(task)

        store.checkAndUpdateStreak(today: today)

        XCTAssertFalse(store.pendingFreezeOffer,
                       "checkAndUpdateStreak must not offer freeze when streak is already 0")
        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    // MARK: - updateStreak: called on same date twice → idempotent

    func testUpdateStreak_sameDateTwice_idempotent() {
        let today        = date(2026, 3, 25)
        let todayWeekday = Calendar.current.component(.weekday, from: today)

        let task = Task(title: "gym", recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true, createdAt: today)
        store.addTask(task)
        store.completeTask(task.id, on: today.dateString)

        store.updateStreak(for: today.dateString)
        store.updateStreak(for: today.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 1,
                       "Calling updateStreak twice for the same date must not double-count")
    }

    // MARK: - Weekly task added and completed same day as injectStreak — streak advances correctly

    func testInjectStreak_completeTodayTask_streakAdvances() {
        // After injectStreak(5), lastCompleted = yesterday.
        // Complete today's task → streak must become 6.
        let today        = date(2026, 3, 25)
        let yesterday    = date(2026, 3, 24)
        let todayWeekday = Calendar.current.component(.weekday, from: today)

        let task = Task(title: "gym", recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true, createdAt: yesterday)
        store.addTask(task)

        // Simulate injectStreak(5)
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5,
                                      lastCompletedDate: yesterday.dateString)

        store.completeTask(task.id, on: today.dateString)
        store.updateStreak(for: today.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 6,
                       "Completing today's task after injectStreak(5) should give streak 6")
        XCTAssertEqual(store.streakData.lastCompletedDate, today.dateString)
    }
}
