import XCTest
@testable import LockIn

final class BlockingStartTimeTests: XCTestCase {

    var store: SharedStore!
    private var todayWeekday: Int!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.blockingstart.\(UUID().uuidString)")
        todayWeekday = Calendar.current.component(.weekday, from: Date())
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// A start time 60 minutes before now (always in the past).
    private func pastStartTime() -> DateComponents {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowMins = (comps.hour ?? 12) * 60 + (comps.minute ?? 0)
        let pastMins = max(0, nowMins - 60)
        return DateComponents(hour: pastMins / 60, minute: pastMins % 60)
    }

    /// A start time 60 minutes from now. Returns nil when running after 22:59 to avoid
    /// day-boundary wrapping — tests that call this should skip when nil is returned.
    private func futureStartTime() -> DateComponents? {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowMins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let futureMins = nowMins + 60
        guard futureMins < 1440 else { return nil }
        return DateComponents(hour: futureMins / 60, minute: futureMins % 60)
    }

    private func addTask(blocksApps: Bool = true, blockingStartTime: DateComponents? = nil) -> Task {
        let task = Task(title: "Task", activeDays: [todayWeekday], blocksApps: blocksApps,
                        blockingStartTime: blockingStartTime)
        store.addTask(task)
        return task
    }

    // MARK: - Task model

    func testTask_blockingStartTime_defaultsNil() {
        let task = Task(title: "Run", activeDays: [2])
        XCTAssertNil(task.blockingStartTime)
    }

    func testTask_blockingStartTime_storesHourAndMinute() {
        let comps = DateComponents(hour: 21, minute: 30)
        let task = Task(title: "Floss", activeDays: [2], blockingStartTime: comps)
        XCTAssertEqual(task.blockingStartTime?.hour, 21)
        XCTAssertEqual(task.blockingStartTime?.minute, 30)
    }

    func testTask_blockingStartTime_encodesAndDecodes() throws {
        let comps = DateComponents(hour: 19, minute: 0)
        let task = Task(title: "Floss", activeDays: [2], blockingStartTime: comps)
        store.addTask(task)

        let data = try JSONEncoder().encode(store.tasks)
        let decoded = try JSONDecoder().decode([Task].self, from: data)

        XCTAssertEqual(decoded[0].blockingStartTime?.hour, 19)
        XCTAssertEqual(decoded[0].blockingStartTime?.minute, 0)
    }

    // MARK: - incompleteBlockingTasks: nil start time (all day)

    func testIncompleteBlockingTasks_nilStartTime_alwaysBlocking() {
        addTask(blocksApps: true, blockingStartTime: nil)
        XCTAssertEqual(store.incompleteBlockingTasks.count, 1)
    }

    func testIncompleteBlockingTasks_nilStartTime_nonBlocking_excluded() {
        addTask(blocksApps: false, blockingStartTime: nil)
        XCTAssertTrue(store.incompleteBlockingTasks.isEmpty)
    }

    // MARK: - incompleteBlockingTasks: midnight start (00:00 = always past)

    func testIncompleteBlockingTasks_midnightStart_alwaysBlocking() {
        // 00:00 start means "from midnight" — always reached by test time
        addTask(blocksApps: true, blockingStartTime: DateComponents(hour: 0, minute: 0))
        XCTAssertEqual(store.incompleteBlockingTasks.count, 1)
    }

    // MARK: - incompleteBlockingTasks: past start time

    func testIncompleteBlockingTasks_pastStartTime_isBlocking() {
        addTask(blocksApps: true, blockingStartTime: pastStartTime())
        XCTAssertEqual(store.incompleteBlockingTasks.count, 1)
    }

    func testIncompleteBlockingTasks_pastStartTime_nonBlocking_excluded() {
        addTask(blocksApps: false, blockingStartTime: pastStartTime())
        XCTAssertTrue(store.incompleteBlockingTasks.isEmpty)
    }

    // MARK: - incompleteBlockingTasks: future start time

    func testIncompleteBlockingTasks_futureStartTime_notBlocking() {
        guard let future = futureStartTime() else { return }
        addTask(blocksApps: true, blockingStartTime: future)
        XCTAssertTrue(store.incompleteBlockingTasks.isEmpty)
    }

    func testIncompleteBlockingTasks_futureStartTime_appearsInBuildTodayTasks() {
        // Task with future start time still shows in Today's list — just doesn't block apps yet.
        guard let future = futureStartTime() else { return }
        addTask(blocksApps: true, blockingStartTime: future)
        XCTAssertEqual(store.buildTodayTasks().count, 1,
                       "Task should appear in today's list even before its blocking window starts")
    }

    // MARK: - incompleteBlockingTasks: completed tasks

    func testIncompleteBlockingTasks_completedPastStartTime_excluded() {
        let task = addTask(blocksApps: true, blockingStartTime: pastStartTime())
        store.completeTask(task.id, on: Date().dateString)
        XCTAssertTrue(store.incompleteBlockingTasks.isEmpty)
    }

    func testIncompleteBlockingTasks_completedNilStartTime_excluded() {
        let task = addTask(blocksApps: true, blockingStartTime: nil)
        store.completeTask(task.id, on: Date().dateString)
        XCTAssertTrue(store.incompleteBlockingTasks.isEmpty)
    }

    // MARK: - incompleteBlockingTasks: mixed tasks

    func testIncompleteBlockingTasks_mixedStartTimes_onlyPastIncluded() {
        guard let future = futureStartTime() else { return }

        addTask(blocksApps: true, blockingStartTime: pastStartTime())   // should block
        addTask(blocksApps: true, blockingStartTime: future)            // not yet blocking
        addTask(blocksApps: true, blockingStartTime: nil)               // always blocks

        XCTAssertEqual(store.incompleteBlockingTasks.count, 2)
    }

    func testIncompleteBlockingTasks_allFuture_noneBlocking() {
        guard let future = futureStartTime() else { return }

        addTask(blocksApps: true, blockingStartTime: future)
        addTask(blocksApps: true, blockingStartTime: future)

        XCTAssertTrue(store.incompleteBlockingTasks.isEmpty)
    }

    // MARK: - Streak unaffected by start time

    func testUpdateStreak_taskWithFutureStartTime_stillCountsForStreak() {
        // The streak requires ALL tasks done — regardless of blocking start time.
        // A task with a future start time is still visible in buildTodayTasks and must be completed.
        guard let future = futureStartTime() else { return }
        let task = addTask(blocksApps: true, blockingStartTime: future)

        // Not completed → streak should NOT increment
        store.updateStreak(for: Date().dateString)
        XCTAssertEqual(store.streakData.currentStreak, 0)

        // Complete it → streak should increment
        store.completeTask(task.id, on: Date().dateString)
        store.updateStreak(for: Date().dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)
    }
}
