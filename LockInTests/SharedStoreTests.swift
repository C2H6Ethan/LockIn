import XCTest
@testable import LockIn

final class SharedStoreTests: XCTestCase {

    var sut: SharedStore!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "test.store.\(UUID().uuidString)"
        sut = SharedStore(suiteName: suite)
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Task CRUD

    func testAddTask_appendsToList() {
        sut.addTask(Task(title: "Run", activeDays: [2]))
        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertEqual(sut.tasks[0].title, "Run")
    }

    func testAddMultipleTasks() {
        sut.addTask(Task(title: "A", activeDays: [2]))
        sut.addTask(Task(title: "B", activeDays: [3]))
        XCTAssertEqual(sut.tasks.count, 2)
    }

    func testRemoveTask() {
        let a = Task(title: "A", activeDays: [2])
        let b = Task(title: "B", activeDays: [4])
        sut.addTask(a)
        sut.addTask(b)
        sut.removeTask(id: a.id)
        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertEqual(sut.tasks[0].id, b.id)
    }

    func testRemoveTask_unknownId_noChange() {
        sut.addTask(Task(title: "A", activeDays: [1]))
        sut.removeTask(id: UUID())
        XCTAssertEqual(sut.tasks.count, 1)
    }

    func testUpdateTask_updatesTitle() {
        var task = Task(title: "Old", activeDays: [2])
        sut.addTask(task)
        task.title = "New"
        sut.updateTask(task)
        XCTAssertEqual(sut.tasks[0].title, "New")
    }

    func testUpdateTask_unknownId_noChange() {
        sut.addTask(Task(title: "A", activeDays: [2]))
        let unknown = Task(title: "X", activeDays: [3])
        sut.updateTask(unknown)
        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertEqual(sut.tasks[0].title, "A")
    }

    // MARK: - Persistence

    func testPersistence_tasksWrittenToUserDefaults() throws {
        sut.addTask(Task(title: "Exercise", activeDays: [4]))
        let data = UserDefaults(suiteName: suite)?.data(forKey: "tasks")
        XCTAssertNotNil(data)
        let decoded = try JSONDecoder().decode([Task].self, from: data!)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].title, "Exercise")
    }

    // MARK: - completeTask / uncompleteTask

    func testCompleteTask_addsToLog() {
        let task = Task(title: "Run", activeDays: [2])
        sut.addTask(task)
        let dateStr = Date().dateString
        sut.completeTask(task.id, on: dateStr)
        XCTAssertTrue(sut.completionLog[dateStr]?.contains(task.id) ?? false)
    }

    func testCompleteTask_multipleOnSameDay() {
        let a = Task(title: "A", activeDays: [2])
        let b = Task(title: "B", activeDays: [2])
        sut.addTask(a)
        sut.addTask(b)
        let dateStr = Date().dateString
        sut.completeTask(a.id, on: dateStr)
        sut.completeTask(b.id, on: dateStr)
        XCTAssertEqual(sut.completionLog[dateStr]?.count, 2)
    }

    func testCompleteTask_idempotent() {
        let task = Task(title: "Run", activeDays: [2])
        sut.addTask(task)
        let dateStr = Date().dateString
        sut.completeTask(task.id, on: dateStr)
        sut.completeTask(task.id, on: dateStr)
        XCTAssertEqual(sut.completionLog[dateStr]?.count, 1)
    }

    func testUncompleteTask_removesFromLog() {
        let task = Task(title: "Run", activeDays: [2])
        sut.addTask(task)
        let dateStr = Date().dateString
        sut.completeTask(task.id, on: dateStr)
        sut.uncompleteTask(task.id, on: dateStr)
        XCTAssertFalse(sut.completionLog[dateStr]?.contains(task.id) ?? false)
    }

    func testCompletionLog_persistsToUserDefaults() throws {
        let task = Task(title: "Run", activeDays: [2])
        sut.addTask(task)
        let dateStr = Date().dateString
        sut.completeTask(task.id, on: dateStr)

        let data = UserDefaults(suiteName: suite)?.data(forKey: "completionLog")
        XCTAssertNotNil(data)
    }

    // MARK: - buildTodayTasks

    func testBuildTodayTasks_taskScheduledForToday_included() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday])
        sut.addTask(task)
        let tasks = sut.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].id, task.id)
        XCTAssertFalse(tasks[0].isCarryOver)
    }

    func testBuildTodayTasks_completedTodayTask_excluded() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday])
        sut.addTask(task)
        sut.completeTask(task.id, on: Date().dateString)
        let tasks = sut.buildTodayTasks()
        XCTAssertTrue(tasks.isEmpty)
    }

    func testBuildTodayTasks_nonBlockingTask_scheduledToday_included() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Floss", activeDays: [todayWeekday], blocksApps: false)
        sut.addTask(task)
        let tasks = sut.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertFalse(tasks[0].blocksApps)
        XCTAssertFalse(tasks[0].isCarryOver)
    }

    func testBuildTodayTasks_carryoverBlocking_included() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yesterdayWeekday != todayWeekday else { return }

        // createdAt must be ≤ yesterday so the createdAt guard allows the carryover
        let task = Task(title: "Run", activeDays: [yesterdayWeekday], blocksApps: true, createdAt: yesterday)
        sut.addTask(task)
        let tasks = sut.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks[0].isCarryOver)
        XCTAssertEqual(tasks[0].originalDay, yesterday.weekdayName)
    }

    func testBuildTodayTasks_carryoverNonBlocking_included() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yesterdayWeekday != todayWeekday else { return }

        let task = Task(title: "Floss", activeDays: [yesterdayWeekday], blocksApps: false, createdAt: yesterday)
        sut.addTask(task)
        let tasks = sut.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks[0].isCarryOver)
        XCTAssertFalse(tasks[0].blocksApps)
    }

    func testBuildTodayTasks_carryoverCompleted_excluded() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yesterdayWeekday != todayWeekday else { return }

        let task = Task(title: "Run", activeDays: [yesterdayWeekday], blocksApps: true, createdAt: yesterday)
        sut.addTask(task)
        sut.completeTask(task.id, on: yesterday.dateString)
        let tasks = sut.buildTodayTasks()
        XCTAssertTrue(tasks.isEmpty)
    }

    func testBuildTodayTasks_multiDayTask_deduplicates() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let yWeekday = Calendar.current.component(.weekday, from: yesterday)
        let tdWeekday = Calendar.current.component(.weekday, from: twoDaysAgo)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yWeekday != tdWeekday, yWeekday != todayWeekday, tdWeekday != todayWeekday else { return }

        let task = Task(title: "Run", activeDays: [yWeekday, tdWeekday], blocksApps: true, createdAt: twoDaysAgo)
        sut.addTask(task)
        let tasks = sut.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].originalDay, yesterday.weekdayName)
    }

    func testBuildTodayTasks_withFixedDate_carryoverIncluded() {
        let testDate = makeDate(year: 2026, month: 3, day: 11) // Wednesday
        // Task scheduled for Monday (weekday 2) — Mar 9 was most recent Monday
        // createdAt = Mar 9 so the guard allows it as a carryover
        let task = Task(title: "Run", activeDays: [2], blocksApps: true,
                        createdAt: makeDate(year: 2026, month: 3, day: 9))
        sut.addTask(task)
        let tasks = sut.buildTodayTasks(on: testDate)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks[0].isCarryOver)
        XCTAssertEqual(tasks[0].originalDay, "Monday")
    }

    func testBuildTodayTasks_withFixedDate_completedPastOccurrence_clearsCarryover() {
        let testDate = makeDate(year: 2026, month: 3, day: 11) // Wednesday
        let task = Task(title: "Run", activeDays: [2], blocksApps: true,
                        createdAt: makeDate(year: 2026, month: 3, day: 9)) // Monday
        sut.addTask(task)
        sut.completeTask(task.id, on: "2026-03-09")
        let tasks = sut.buildTodayTasks(on: testDate)
        XCTAssertTrue(tasks.isEmpty)
    }

    func testBuildTodayTasks_newTask_doesNotShowAsCarryoverForPastDays() {
        // Task created today for yesterday's weekday must NOT appear as carryover
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayWeekday = Calendar.current.component(.weekday, from: yesterday)
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        guard yesterdayWeekday != todayWeekday else { return }

        // createdAt = NOW (today) — task didn't exist yesterday
        let task = Task(title: "Run", activeDays: [yesterdayWeekday], blocksApps: true)
        sut.addTask(task)
        let tasks = sut.buildTodayTasks()
        XCTAssertTrue(tasks.isEmpty, "New task should not appear as carryover for dates before it was created")
    }

    // MARK: - incompleteBlockingTasks

    func testIncompleteBlockingTasks_nonBlockingTask_excluded() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        sut.addTask(Task(title: "Floss", activeDays: [todayWeekday], blocksApps: false))
        XCTAssertTrue(sut.incompleteBlockingTasks.isEmpty)
    }

    func testIncompleteBlockingTasks_blockingTask_included() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        sut.addTask(Task(title: "Run", activeDays: [todayWeekday], blocksApps: true))
        XCTAssertEqual(sut.incompleteBlockingTasks.count, 1)
    }

    func testIncompleteBlockingTasks_completedToday_empty() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday], blocksApps: true)
        sut.addTask(task)
        sut.completeTask(task.id, on: Date().dateString)
        XCTAssertTrue(sut.incompleteBlockingTasks.isEmpty)
    }

    // MARK: - lockExpiresAt / isLocked

    func testLockExpiresAt_defaultsNil() {
        XCTAssertNil(sut.lockExpiresAt)
    }

    func testIsLocked_whenNil_false() {
        XCTAssertFalse(sut.isLocked)
    }

    func testIsLocked_whenFuture_true() {
        sut.lockExpiresAt = Date().addingTimeInterval(3600)
        XCTAssertTrue(sut.isLocked)
    }

    func testIsLocked_whenPast_false() {
        sut.lockExpiresAt = Date().addingTimeInterval(-1)
        XCTAssertFalse(sut.isLocked)
    }

    func testLockExpiresAt_canBeCleared() {
        sut.lockExpiresAt = Date().addingTimeInterval(3600)
        sut.lockExpiresAt = nil
        XCTAssertNil(sut.lockExpiresAt)
        XCTAssertFalse(sut.isLocked)
    }

    // MARK: - streakData

    func testStreakData_defaultsToZero() {
        XCTAssertEqual(sut.streakData.currentStreak, 0)
        XCTAssertEqual(sut.streakData.longestStreak, 0)
        XCTAssertNil(sut.streakData.lastCompletedDate)
    }

    func testStreakData_canBeSet() {
        sut.streakData = StreakData(currentStreak: 5, longestStreak: 10, lastCompletedDate: "2026-03-11")
        XCTAssertEqual(sut.streakData.currentStreak, 5)
        XCTAssertEqual(sut.streakData.longestStreak, 10)
        XCTAssertEqual(sut.streakData.lastCompletedDate, "2026-03-11")
    }

    func testStreakData_persistsToUserDefaults() throws {
        sut.streakData = StreakData(currentStreak: 3, longestStreak: 7)
        let data = UserDefaults(suiteName: suite)?.data(forKey: "streakData")
        XCTAssertNotNil(data)
        let decoded = try JSONDecoder().decode(StreakData.self, from: data!)
        XCTAssertEqual(decoded.currentStreak, 3)
    }

    // MARK: - unblockExpiresAt

    func testUnblockExpiresAt_defaultsNil() {
        XCTAssertNil(sut.unblockExpiresAt)
    }

    func testUnblockExpiresAt_canBeSet() {
        let date = Date().addingTimeInterval(60)
        sut.unblockExpiresAt = date
        XCTAssertEqual(
            sut.unblockExpiresAt?.timeIntervalSinceReferenceDate ?? 0,
            date.timeIntervalSinceReferenceDate,
            accuracy: 0.001
        )
    }

    func testUnblockExpiresAt_canBeCleared() {
        sut.unblockExpiresAt = Date()
        sut.unblockExpiresAt = nil
        XCTAssertNil(sut.unblockExpiresAt)
    }

    // MARK: - hasCompletedOnboarding

    func testHasCompletedOnboarding_defaultsFalse() {
        XCTAssertFalse(sut.hasCompletedOnboarding)
    }

    func testHasCompletedOnboarding_canBeSetTrue() {
        sut.hasCompletedOnboarding = true
        XCTAssertTrue(sut.hasCompletedOnboarding)
    }

    func testHasCompletedOnboarding_persists() {
        sut.hasCompletedOnboarding = true
        let defaults = UserDefaults(suiteName: suite)!
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}
