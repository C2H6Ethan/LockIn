import XCTest
@testable import LockIn

final class OneTimeTaskTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.once.\(UUID().uuidString)")
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDate(daysFromToday offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    // MARK: - Appearance

    func testOnceTask_appearsOnStartDate() {
        let today = Date()
        let task = Task(title: "Dentist", recurrence: .once(startDate: today.dateString))
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Dentist")
        XCTAssertTrue(result[0].isOnce)
    }

    func testOnceTask_doesNotAppearBeforeStartDate() {
        let tomorrow = makeDate(daysFromToday: 1)
        let task = Task(title: "Dentist", recurrence: .once(startDate: tomorrow.dateString))
        store.addTask(task)

        let result = store.buildTodayTasks(on: Date())

        XCTAssertTrue(result.isEmpty)
    }

    func testOnceTask_appearsOnStartDate_notCarryOver() {
        let today = Date()
        let task = Task(title: "Dentist", recurrence: .once(startDate: today.dateString))
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)

        XCTAssertFalse(result[0].isCarryOver)
        XCTAssertNil(result[0].originalDay)
    }

    func testOnceTask_appearsAsCarryover_afterStartDate() {
        let yesterday = makeDate(daysFromToday: -1)
        let task = Task(title: "Dentist", recurrence: .once(startDate: yesterday.dateString))
        store.addTask(task)

        let result = store.buildTodayTasks(on: Date())

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isCarryOver)
        XCTAssertNotNil(result[0].originalDay)
        XCTAssertTrue(result[0].isOnce)
    }

    func testOnceTask_appearsEveryDay_untilCompleted() {
        let twoDaysAgo = makeDate(daysFromToday: -2)
        let task = Task(title: "Dentist", recurrence: .once(startDate: twoDaysAgo.dateString))
        store.addTask(task)

        let result = store.buildTodayTasks(on: Date())

        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].isOnce)
    }

    // MARK: - Completion and deferred delete

    func testOnceTask_notDeletedImmediatelyOnCompletion() {
        let today = Date()
        let task = Task(title: "Dentist", recurrence: .once(startDate: today.dateString))
        store.addTask(task)

        store.completeTask(task.id, on: today.dateString)

        XCTAssertEqual(store.tasks.count, 1, "Once task must NOT be deleted immediately — stays for completed list")
    }

    func testOnceTask_deletedByCheckAndUpdateStreak_nextDay() {
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let task = Task(title: "Dentist", recurrence: .once(startDate: yesterday.dateString))
        store.addTask(task)
        store.completeTask(task.id, on: yesterday.dateString)
        XCTAssertEqual(store.tasks.count, 1)

        store.checkAndUpdateStreak(today: today)

        XCTAssertTrue(store.tasks.isEmpty, "Once task completed yesterday must be deleted on next day's check")
    }

    func testOnceTask_notDeletedByCheckAndUpdateStreak_sameDay() {
        let today = Date()
        let task = Task(title: "Dentist", recurrence: .once(startDate: today.dateString))
        store.addTask(task)
        store.completeTask(task.id, on: today.dateString)

        store.checkAndUpdateStreak(today: today)

        XCTAssertEqual(store.tasks.count, 1, "Once task completed today must NOT be deleted yet")
    }

    func testOnceTask_doesNotReappearAfterCompletion() {
        let today = Date()
        let task = Task(title: "Dentist", recurrence: .once(startDate: today.dateString))
        store.addTask(task)

        store.completeTask(task.id, on: today.dateString)

        let result = store.buildTodayTasks(on: Date())
        XCTAssertTrue(result.isEmpty, "Completed once task must not reappear")
    }

    func testOnceTask_logsCompletionOnToday() {
        let yesterday = makeDate(daysFromToday: -1)
        let task = Task(title: "Dentist", recurrence: .once(startDate: yesterday.dateString))
        store.addTask(task)

        let tasks = store.buildTodayTasks(on: Date())
        XCTAssertEqual(tasks.count, 1)
        // scheduledDateString is always today for once tasks
        XCTAssertEqual(tasks[0].scheduledDateString, Date().dateString)
    }

    func testWeeklyTask_notAutoDeleted_onCompletion() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(task)

        store.completeTask(task.id, on: Date().dateString)

        XCTAssertEqual(store.tasks.count, 1, "Weekly task must NOT be auto-deleted")
    }

    // MARK: - isOnce flag in TodayTask

    func testWeeklyTask_isOnce_isFalse() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))

        let result = store.buildTodayTasks(on: Date())

        XCTAssertFalse(result[0].isOnce)
    }

    func testOnceTask_isOnce_isTrue() {
        let task = Task(title: "Dentist", recurrence: .once(startDate: Date().dateString))
        store.addTask(task)

        let result = store.buildTodayTasks(on: Date())

        XCTAssertTrue(result[0].isOnce)
    }

    // MARK: - TaskRecurrence convenience init

    func testTask_weeklyConvenienceInit_setsRecurrence() {
        let task = Task(title: "Run", activeDays: [2, 3])
        XCTAssertEqual(task.activeDays, [2, 3])
        XCTAssertFalse(task.isOnce)
    }

    func testTask_onceRecurrence_activeDaysEmpty() {
        let task = Task(title: "Dentist", recurrence: .once(startDate: Date().dateString))
        XCTAssertTrue(task.activeDays.isEmpty)
        XCTAssertTrue(task.isOnce)
    }

    func testTask_onceStartDate_returnsCorrectDate() {
        let dateString = Date().dateString
        let task = Task(title: "Dentist", recurrence: .once(startDate: dateString))
        XCTAssertEqual(task.onceStartDate, dateString)
    }
}
