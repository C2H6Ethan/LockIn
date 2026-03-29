import XCTest
@testable import LockIn

/// Reproduces the bug from 2026-03-28: after a legitimate streak reset to 0,
/// editing a task's schedule triggered reconcileStreakAfterEdit which incorrectly
/// resurrected the streak to 1 without all tasks being completed.
final class AddTaskDeleteStreakTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.adddelete.\(UUID().uuidString)")
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour
        return Calendar.current.date(from: c)!
    }

    // MARK: - Bug: reconcileStreakAfterEdit resurrects a dead streak

    /// After streak was legitimately reset to 0, editing a task's schedule
    /// should NOT bring the streak back. reconcileStreakAfterEdit checks if
    /// the "next day" after lastCompletedDate is now complete and blindly
    /// increments — even when the streak is 0.
    func testEditTaskAfterReset_shouldNotResurrectStreak() {
        let march27 = makeDate(year: 2026, month: 3, day: 27)
        let march28 = makeDate(year: 2026, month: 3, day: 28)
        let march29 = makeDate(year: 2026, month: 3, day: 29)

        let weekday28 = Calendar.current.component(.weekday, from: march28)
        let weekday29 = Calendar.current.component(.weekday, from: march29)

        // Task scheduled for both days, completed on March 28
        let gymTask = Task(title: "gym", activeDays: [weekday28, weekday29], blocksApps: true, createdAt: march27)
        store.addTask(gymTask)
        store.completeTask(gymTask.id, on: march28.dateString)

        // Streak legitimately reset to 0. lastCompletedDate stayed at March 27
        // (rolled back by add-task decrement before midnight).
        store.streakData = StreakData(currentStreak: 0, longestStreak: 8, lastCompletedDate: march27.dateString)

        // Edit gym to remove March 29 from its schedule
        var edited = gymTask
        edited.recurrence = .weekly(days: [weekday28])
        store.updateTask(edited)

        // BUG: reconcileStreakAfterEdit sees March 27 is "complete" (no tasks remain),
        // then checks March 28 — gym was completed there — and calls updateStreak
        // which sets streak to 1. But streak was 0 for a reason.
        XCTAssertEqual(store.streakData.currentStreak, 0,
            "Editing a task should not resurrect a streak that was legitimately reset to 0")
    }

    /// Same scenario but with multiple tasks — only one was completed on the
    /// gap day. Editing should still not bump the streak.
    func testEditTaskAfterReset_multipleTasksOneIncomplete_staysZero() {
        let march27 = makeDate(year: 2026, month: 3, day: 27)
        let march28 = makeDate(year: 2026, month: 3, day: 28)

        let weekday28 = Calendar.current.component(.weekday, from: march28)

        let task1 = Task(title: "gym", activeDays: [weekday28], blocksApps: true, createdAt: march27)
        let task2 = Task(title: "leetcode", activeDays: [weekday28], blocksApps: true, createdAt: march27)
        store.addTask(task1)
        store.addTask(task2)

        // Only task1 completed on March 28 — task2 missed
        store.completeTask(task1.id, on: march28.dateString)

        // Streak reset to 0
        store.streakData = StreakData(currentStreak: 0, longestStreak: 5, lastCompletedDate: march27.dateString)

        // Edit task2 to remove it from March 28's weekday
        let otherWeekday = weekday28 == 7 ? 1 : weekday28 + 1
        var edited = task2
        edited.recurrence = .weekly(days: [otherWeekday])
        store.updateTask(edited)

        // After edit, March 28 now only has task1 (which is completed).
        // reconcileStreakAfterEdit should NOT count this as a new streak day.
        XCTAssertEqual(store.streakData.currentStreak, 0,
            "Moving a missed task away should not resurrect a dead streak")
    }
}
