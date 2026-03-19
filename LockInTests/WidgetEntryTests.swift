import XCTest
@testable import LockIn

final class WidgetEntryTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.widget.\(UUID().uuidString)")
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func addTask(on weekday: Int, title: String = "Task", blocksApps: Bool = true) -> Task {
        let task = Task(title: title, activeDays: [weekday], blocksApps: blocksApps)
        store.addTask(task)
        return task
    }

    private var todayWeekday: Int { Calendar.current.component(.weekday, from: Date()) }

    // MARK: - allDone

    func testBuildEntry_allDone_whenNoTasksScheduledToday() {
        let entry = LockInWidgetEntry.build(store: store)
        // No tasks at all → total == 0 → allDone should be false (nothing to complete)
        XCTAssertFalse(entry.allDone)
        XCTAssertEqual(entry.incompleteCount, 0)
    }

    func testBuildEntry_allDone_whenAllTasksCompleted() {
        let task = addTask(on: todayWeekday, title: "Run")
        store.completeTask(task.id, on: Date().dateString)

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertTrue(entry.allDone)
        XCTAssertEqual(entry.incompleteCount, 0)
    }

    func testBuildEntry_notAllDone_whenIncompleteTasksRemain() {
        addTask(on: todayWeekday, title: "Run")

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertFalse(entry.allDone)
        XCTAssertEqual(entry.incompleteCount, 1)
    }

    // MARK: - totalCount

    func testBuildEntry_totalCount_includesCompletedAndIncomplete() {
        let t1 = addTask(on: todayWeekday, title: "Run")
        let t2 = addTask(on: todayWeekday, title: "Meditate")
        store.completeTask(t1.id, on: Date().dateString) // complete one

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertEqual(entry.totalCount, 2)
        XCTAssertEqual(entry.incompleteCount, 1)
    }

    // MARK: - taskTitles overflow

    func testBuildEntry_taskTitles_cappedAtTwo() {
        addTask(on: todayWeekday, title: "Task A")
        addTask(on: todayWeekday, title: "Task B")
        addTask(on: todayWeekday, title: "Task C")

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertEqual(entry.taskTitles.count, 2)
        XCTAssertEqual(entry.incompleteCount, 3)
    }

    func testBuildEntry_taskTitles_exactlyTwo_whenTwoTasks() {
        addTask(on: todayWeekday, title: "Run")
        addTask(on: todayWeekday, title: "Meditate")

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertEqual(entry.taskTitles.count, 2)
        XCTAssertTrue(entry.taskTitles.contains("Run"))
        XCTAssertTrue(entry.taskTitles.contains("Meditate"))
    }

    func testBuildEntry_taskTitles_emptyWhenAllDone() {
        let task = addTask(on: todayWeekday, title: "Run")
        store.completeTask(task.id, on: Date().dateString)

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertTrue(entry.taskTitles.isEmpty)
    }

    // MARK: - ghost IDs (completed-then-deleted tasks)

    func testBuildEntry_deletedTaskCompletionLog_notCountedInTotal() {
        // Complete a task then delete it — its ID stays in completionLog but should not inflate total
        let ghost = addTask(on: todayWeekday, title: "Ghost Task")
        store.completeTask(ghost.id, on: Date().dateString)
        store.removeTask(id: ghost.id)

        let live = addTask(on: todayWeekday, title: "Live Task")
        _ = live  // incomplete

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertEqual(entry.totalCount, 1, "Deleted task's completion should not count toward total")
        XCTAssertEqual(entry.incompleteCount, 1)
        XCTAssertFalse(entry.allDone)
    }

    func testBuildEntry_multipleGhostIDs_noneCountTowardTotal() {
        // Several tasks completed and deleted — total should reflect only live tasks
        for i in 1...3 {
            let ghost = addTask(on: todayWeekday, title: "Ghost \(i)")
            store.completeTask(ghost.id, on: Date().dateString)
            store.removeTask(id: ghost.id)
        }
        let live = addTask(on: todayWeekday, title: "Live Task")
        store.completeTask(live.id, on: Date().dateString)

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertEqual(entry.totalCount, 1)
        XCTAssertEqual(entry.incompleteCount, 0)
        XCTAssertTrue(entry.allDone)
    }

    // MARK: - streak

    func testBuildEntry_streak_reflectsStoreValue() {
        store.streakData = StreakData(currentStreak: 14, longestStreak: 14)

        let entry = LockInWidgetEntry.build(store: store)

        XCTAssertEqual(entry.streak, 14)
    }

    func testBuildEntry_streak_zeroByDefault() {
        let entry = LockInWidgetEntry.build(store: store)
        XCTAssertEqual(entry.streak, 0)
    }

    // MARK: - date

    func testBuildEntry_date_isApproximatelyNow() {
        let before = Date()
        let entry = LockInWidgetEntry.build(store: store)
        let after = Date()
        XCTAssertTrue(entry.date >= before && entry.date <= after)
    }
}
