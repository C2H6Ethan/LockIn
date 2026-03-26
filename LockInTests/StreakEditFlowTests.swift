import XCTest
@testable import LockIn

/// Full user-flow test: 3 tasks today + 1 tomorrow, existing 5 streak.
/// Complete today → 6, move tomorrow→today → 5, complete → 6,
/// undo → 5, move back to tomorrow → 6, next day complete → 7.
final class StreakEditFlowTests: XCTestCase {

    var store: SharedStore!

    // Fixed dates: today = Wed March 11 2026 (weekday 4), tomorrow = Thu March 12 (weekday 5)
    let today    = { () -> Date in var c = DateComponents(); c.year = 2026; c.month = 3; c.day = 11; c.hour = 12; return Calendar.current.date(from: c)! }()
    let tomorrow = { () -> Date in var c = DateComponents(); c.year = 2026; c.month = 3; c.day = 12; c.hour = 12; return Calendar.current.date(from: c)! }()
    let yesterday = { () -> Date in var c = DateComponents(); c.year = 2026; c.month = 3; c.day = 10; c.hour = 12; return Calendar.current.date(from: c)! }()

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.streakeditflow.\(UUID().uuidString)")
        store.streakFreezeCount = 0
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    func testFullEditFlow_streakCorrectAtEveryStep() {
        // --- Setup: 3 weekly tasks for today (Wed, weekday 4), 1 once task for tomorrow ---
        let task1 = Task(title: "Meditate", activeDays: [4], blocksApps: true, createdAt: yesterday)
        let task2 = Task(title: "Exercise", activeDays: [4], blocksApps: true, createdAt: yesterday)
        let task3 = Task(title: "Read", activeDays: [4], blocksApps: true, createdAt: yesterday)
        var tomorrowTask = Task(title: "Journal", recurrence: .once(startDate: tomorrow.dateString),
                                blocksApps: true, createdAt: yesterday)
        store.addTask(task1)
        store.addTask(task2)
        store.addTask(task3)
        store.addTask(tomorrowTask)

        // Pre-existing 5-day streak, lastCompletedDate = yesterday
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5,
                                      lastCompletedDate: yesterday.dateString)

        // --- Step 1: Complete all 3 today → streak 6 ---
        store.completeTask(task1.id, on: today.dateString)
        store.completeTask(task2.id, on: today.dateString)
        store.completeTask(task3.id, on: today.dateString)
        store.updateStreak(for: today.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 6, "After completing all 3 today tasks, streak should be 6")

        // --- Step 2: Edit tomorrow task to today → streak should drop to 5 ---
        tomorrowTask = Task(id: tomorrowTask.id, title: tomorrowTask.title,
                            recurrence: .once(startDate: today.dateString),
                            blocksApps: tomorrowTask.blocksApps, createdAt: tomorrowTask.createdAt)
        store.updateTask(tomorrowTask)
        XCTAssertEqual(store.streakData.currentStreak, 5, "Moving incomplete task to today should drop streak to 5")

        // --- Step 3: Complete the moved task → streak back to 6 ---
        store.completeTask(tomorrowTask.id, on: today.dateString)
        store.updateStreak(for: today.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 6, "Completing moved task should restore streak to 6")

        // --- Step 4: Undo the completion → streak drops to 5 ---
        store.uncompleteTask(tomorrowTask.id, on: today.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 5, "Undoing completion should drop streak to 5")

        // --- Step 5: Edit task back to tomorrow → streak should be 6 again ---
        tomorrowTask = Task(id: tomorrowTask.id, title: tomorrowTask.title,
                            recurrence: .once(startDate: tomorrow.dateString),
                            blocksApps: tomorrowTask.blocksApps, createdAt: tomorrowTask.createdAt)
        store.updateTask(tomorrowTask)
        XCTAssertEqual(store.streakData.currentStreak, 6, "Moving task back to tomorrow should restore streak to 6")

        // --- Step 6: Wait until tomorrow, complete that task → streak 7 ---
        store.completeTask(tomorrowTask.id, on: tomorrow.dateString)
        store.updateStreak(for: tomorrow.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 7, "Completing task tomorrow should give streak 7")
    }
}
