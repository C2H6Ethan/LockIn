import XCTest
@testable import LockIn

final class AddTaskTests: XCTestCase {

    var store: SharedStore!
    var mockApplier: MockShieldApplier!
    var blocking: BlockingService!
    var viewModel: TodayViewModel!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.addtask.\(UUID().uuidString)")
        mockApplier = MockShieldApplier()
        blocking = BlockingService(store: store, applier: mockApplier)
        viewModel = TodayViewModel(store: store, blocking: blocking)
    }

    override func tearDown() {
        viewModel = nil
        blocking = nil
        mockApplier = nil
        store = nil
        super.tearDown()
    }

    // MARK: - addTask via ViewModel

    func testAddTask_savesToStore() {
        viewModel.addTask(title: "Run", activeDays: [2, 4], blocksApps: true)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].title, "Run")
        XCTAssertEqual(store.tasks[0].activeDays, [2, 4])
        XCTAssertTrue(store.tasks[0].blocksApps)
    }

    func testAddTask_nonBlocking_savedCorrectly() {
        viewModel.addTask(title: "Floss", activeDays: [1, 2, 3, 4, 5, 6, 7], blocksApps: false)
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertFalse(store.tasks[0].blocksApps)
    }

    func testAddTask_refreshesTodayTasks() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        viewModel.onAppear()
        XCTAssertTrue(viewModel.todayTasks.isEmpty)

        viewModel.addTask(title: "Run", activeDays: [todayWeekday], blocksApps: true)

        XCTAssertEqual(viewModel.todayTasks.count, 1)
        XCTAssertEqual(viewModel.todayTasks[0].title, "Run")
    }

    func testAddTask_taskNotScheduledToday_notInTodayTasks() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let otherWeekday = todayWeekday == 1 ? 2 : 1
        viewModel.onAppear()

        viewModel.addTask(title: "Run", activeDays: [otherWeekday], blocksApps: false)

        XCTAssertTrue(viewModel.todayTasks.isEmpty)
        XCTAssertEqual(store.tasks.count, 1)
    }

    func testAddTask_updatesShields() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        viewModel.addTask(title: "Run", activeDays: [todayWeekday], blocksApps: true)
        XCTAssertGreaterThan(mockApplier.removeCallCount, 0)
    }

    func testAddTask_dismissesSheet() {
        viewModel.showingAddTask = true
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        viewModel.addTask(title: "Run", activeDays: [todayWeekday], blocksApps: true)
        XCTAssertFalse(viewModel.showingAddTask)
    }

    func testAddTask_multipleTasks_allSaved() {
        viewModel.addTask(title: "Run", activeDays: [2], blocksApps: true)
        viewModel.addTask(title: "Meditate", activeDays: [3, 4], blocksApps: false)
        XCTAssertEqual(store.tasks.count, 2)
    }

    func testAddTask_postsHabitsDidChangeNotification() {
        let expectation = XCTestExpectation(description: "habitsDidChange posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .habitsDidChange,
            object: nil,
            queue: .main
        ) { _ in expectation.fulfill() }

        viewModel.addTask(title: "Run", activeDays: [2], blocksApps: true)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
