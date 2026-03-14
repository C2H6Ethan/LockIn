import XCTest
@testable import LockIn

// MARK: - Test doubles

final class MockStepProvider: StepProviding {
    var mockSteps: Int = 0
    var isAvailable: Bool = true
    func stepsToday() async -> Int { mockSteps }
    func startObserving(onChange: @escaping () -> Void) {}
    func stopObserving() {}
}

// MARK: - Tests

final class StepGoalTests: XCTestCase {

    var store: SharedStore!
    var suite: String!
    var mockProvider: MockStepProvider!
    var viewModel: TodayViewModel!

    override func setUp() {
        super.setUp()
        suite = "test.stepgoal.\(UUID().uuidString)"
        store = SharedStore(suiteName: suite)
        mockProvider = MockStepProvider()
        let blocking = BlockingService(store: store, applier: MockShieldApplier())
        viewModel = TodayViewModel(store: store, blocking: blocking, stepProvider: mockProvider)
    }

    override func tearDown() {
        viewModel = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Task model

    func testTask_defaultStepTargetIsNil() {
        let task = Task(title: "Run", activeDays: [2])
        XCTAssertNil(task.stepTarget)
    }

    func testTask_canHaveStepTarget() {
        let task = Task(title: "Walk", activeDays: [2, 4], stepTarget: 10_000)
        XCTAssertEqual(task.stepTarget, 10_000)
    }

    func testTask_encodesDecodesWithStepTarget() throws {
        let task = Task(title: "Walk", recurrence: .weekly(days: [2]), blocksApps: true, stepTarget: 5_000)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)
        XCTAssertEqual(decoded.stepTarget, 5_000)
    }

    func testTask_nilStepTarget_encodesDecodes() throws {
        let task = Task(title: "Run", recurrence: .weekly(days: [2]), blocksApps: true, stepTarget: nil)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)
        XCTAssertNil(decoded.stepTarget)
    }

    func testTask_legacyJSON_missingStepTarget_decodesAsNil() throws {
        // Old JSON without stepTarget key — must decode gracefully
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "title": "Run",
            "recurrence": {"weekly": {"days": [2]}},
            "blocksApps": true,
            "createdAt": \(Date().timeIntervalSinceReferenceDate)
        }
        """
        let decoded = try JSONDecoder().decode(Task.self, from: json.data(using: .utf8)!)
        XCTAssertNil(decoded.stepTarget)
    }

    // MARK: - TodayTask carries stepTarget

    func testBuildTodayTasks_stepTask_carriesStepTarget() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Walk", activeDays: [todayWeekday], stepTarget: 10_000))
        let tasks = store.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].stepTarget, 10_000)
    }

    func testBuildTodayTasks_regularTask_stepTargetNil() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        let tasks = store.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertNil(tasks[0].stepTarget)
    }

    func testBuildTodayTasks_onceStepTask_carriesStepTarget() {
        let task = Task(
            title: "Walk 5k",
            recurrence: .once(startDate: Date().dateString),
            blocksApps: true,
            stepTarget: 5_000
        )
        store.addTask(task)
        let tasks = store.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].stepTarget, 5_000)
    }

    // MARK: - stepsToday

    func testStepsToday_startsAtZero() {
        XCTAssertEqual(viewModel.stepsToday, 0)
    }

    func testStepsToday_updatedAfterRefresh() async {
        mockProvider.mockSteps = 7_500
        await viewModel.refreshStepCounts()
        XCTAssertEqual(viewModel.stepsToday, 7_500)
    }

    // MARK: - autoCompleteStepTasksIfNeeded

    func testAutoComplete_stepsMetTarget_completesTask() async {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Walk 5k", activeDays: [todayWeekday], stepTarget: 5_000)
        store.addTask(task)
        viewModel.onAppear()

        mockProvider.mockSteps = 6_000
        await viewModel.refreshStepCounts()

        XCTAssertTrue(viewModel.todayTasks.isEmpty)
        XCTAssertTrue(store.completionLog[Date().dateString]?.contains(task.id) ?? false)
    }

    func testAutoComplete_stepsExactlyTarget_completesTask() async {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Walk 10k", activeDays: [todayWeekday], stepTarget: 10_000)
        store.addTask(task)
        viewModel.onAppear()

        mockProvider.mockSteps = 10_000
        await viewModel.refreshStepCounts()

        XCTAssertTrue(viewModel.todayTasks.isEmpty)
    }

    func testAutoComplete_stepsBelowTarget_doesNotComplete() async {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Walk 10k", activeDays: [todayWeekday], stepTarget: 10_000)
        store.addTask(task)
        viewModel.onAppear()

        mockProvider.mockSteps = 3_000
        await viewModel.refreshStepCounts()

        XCTAssertEqual(viewModel.todayTasks.count, 1)
    }

    func testAutoComplete_nonStepTask_unaffected() async {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday]) // no stepTarget
        store.addTask(task)
        viewModel.onAppear()

        mockProvider.mockSteps = 99_000
        await viewModel.refreshStepCounts()

        XCTAssertEqual(viewModel.todayTasks.count, 1)
    }

    func testAutoComplete_bothTargetsMet_completesAll() async {
        // Regression: autoCompleteStepTasksIfNeeded must not stop after the first completion.
        // Both tasks have targets below stepsToday — both must be completed.
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let taskA = Task(title: "Walk 1k", activeDays: [todayWeekday], stepTarget: 1_000)
        let taskB = Task(title: "Walk 3k", activeDays: [todayWeekday], stepTarget: 3_000)
        store.addTask(taskA)
        store.addTask(taskB)
        viewModel.onAppear()
        XCTAssertEqual(viewModel.todayTasks.count, 2)

        mockProvider.mockSteps = 5_000
        await viewModel.refreshStepCounts()

        XCTAssertTrue(viewModel.todayTasks.isEmpty)
        XCTAssertTrue(store.completionLog[Date().dateString]?.contains(taskA.id) ?? false)
        XCTAssertTrue(store.completionLog[Date().dateString]?.contains(taskB.id) ?? false)
    }

    func testAutoComplete_multipleStepTasks_completesAllMet() async {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let low = Task(title: "Walk 1k",  activeDays: [todayWeekday], stepTarget: 1_000)
        let high = Task(title: "Walk 10k", activeDays: [todayWeekday], stepTarget: 10_000)
        store.addTask(low)
        store.addTask(high)
        viewModel.onAppear()

        mockProvider.mockSteps = 5_000
        await viewModel.refreshStepCounts()

        // low target met, high target not met
        XCTAssertEqual(viewModel.todayTasks.count, 1)
        XCTAssertEqual(viewModel.todayTasks[0].title, "Walk 10k")
    }
}
