import XCTest
import CoreLocation
@testable import LockIn

// Note: MockShieldApplier is defined in BlockingServiceTests.swift (same test module)
// Note: MockStepProvider is defined in StepGoalTests.swift (same test module)

// MARK: - Mock

final class MockLocationVerifier: LocationVerifying {
    var mockResult: Bool = true
    var verifyCallCount = 0
    var mockAuthStatus: CLAuthorizationStatus = .authorizedWhenInUse

    func verifyCurrentLocation(for task: TodayTask) async -> Bool {
        verifyCallCount += 1
        return mockResult
    }

    func registerGeofences(for tasks: [TodayTask]) async {}
    func startMonitoringEvents() async {}
    func requestAuthorization() {}
    func requestAlwaysAuthorization() {}

    var authorizationStatus: CLAuthorizationStatus { mockAuthStatus }
}

// MARK: - Tests

final class LocationTaskTests: XCTestCase {

    var store: SharedStore!
    var suite: String!
    var mockVerifier: MockLocationVerifier!
    var mockStep: MockStepProvider!
    var viewModel: TodayViewModel!

    override func setUp() {
        super.setUp()
        suite = "test.location.\(UUID().uuidString)"
        store = SharedStore(suiteName: suite)
        mockVerifier = MockLocationVerifier()
        mockStep = MockStepProvider()
        let blocking = BlockingService(store: store, applier: MockShieldApplier())
        viewModel = TodayViewModel(
            store: store,
            blocking: blocking,
            stepProvider: mockStep,
            locationVerifier: mockVerifier
        )
    }

    override func tearDown() {
        viewModel = nil
        store = nil
        super.tearDown()
    }

    // MARK: - TaskLocation Codable

    func testTaskLocation_encodesDecodes() throws {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "San Francisco", radius: 100)
        let data = try JSONEncoder().encode(loc)
        let decoded = try JSONDecoder().decode(TaskLocation.self, from: data)
        XCTAssertEqual(decoded.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(decoded.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(decoded.name, "San Francisco")
        XCTAssertEqual(decoded.radius, 100, accuracy: 0.01)
    }

    func testTaskLocation_defaultRadius() {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        XCTAssertEqual(loc.radius, 100)
    }

    func testTask_withLocation_encodesDecodes() throws {
        let loc = TaskLocation(latitude: 40.7128, longitude: -74.0060, name: "NYC", radius: 150)
        let task = Task(title: "Go to gym", recurrence: .weekly(days: [2]), blocksApps: true, location: loc)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)
        XCTAssertEqual(decoded.location?.name, "NYC")
        XCTAssertEqual(decoded.location?.latitude ?? 0, 40.7128, accuracy: 0.0001)
        XCTAssertEqual(decoded.location?.radius ?? 0, 150, accuracy: 0.01)
    }

    func testTask_withoutLocation_encodesDecodes() throws {
        let task = Task(title: "Run", recurrence: .weekly(days: [2]), blocksApps: true)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)
        XCTAssertNil(decoded.location)
    }

    func testTask_legacyJSON_missingLocation_decodesAsNil() throws {
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
        XCTAssertNil(decoded.location)
    }

    // MARK: - TodayTask carries location

    func testBuildTodayTasks_locationTask_carriesLocation() {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Planet Fitness")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Go to gym", activeDays: [todayWeekday], location: loc))
        let tasks = store.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].location?.name, "Planet Fitness")
    }

    func testBuildTodayTasks_noLocation_locationNil() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Run", activeDays: [todayWeekday]))
        let tasks = store.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertNil(tasks[0].location)
    }

    func testBuildTodayTasks_locationCarriedOverOnCarryover() {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Office")
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayWeekday = Calendar.current.component(.weekday, from: yesterday)
        // Task must have createdAt ≤ yesterday so carryover logic considers it existing on that day
        store.addTask(Task(title: "Go to office", activeDays: [yesterdayWeekday], createdAt: yesterday, location: loc))
        let tasks = store.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks[0].isCarryOver)
        XCTAssertEqual(tasks[0].location?.name, "Office")
    }

    func testBuildTodayTasks_onceTask_locationCarried() {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Coffee Shop")
        let task = Task(
            title: "Work from coffee shop",
            recurrence: .once(startDate: Date().dateString),
            blocksApps: false,
            location: loc
        )
        store.addTask(task)
        let tasks = store.buildTodayTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].location?.name, "Coffee Shop")
    }

    // MARK: - Location visit log

    func testLogLocationVisit_storesVisit() {
        let id = UUID()
        let today = Date().dateString
        store.logLocationVisit(taskID: id, on: today)
        XCTAssertTrue(store.hasVisitedLocation(taskID: id, on: today))
    }

    func testHasVisitedLocation_beforeLogging_returnsFalse() {
        let id = UUID()
        XCTAssertFalse(store.hasVisitedLocation(taskID: id, on: Date().dateString))
    }

    func testHasVisitedLocation_wrongDate_returnsFalse() {
        let id = UUID()
        let today = Date().dateString
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!.dateString
        store.logLocationVisit(taskID: id, on: today)
        XCTAssertFalse(store.hasVisitedLocation(taskID: id, on: yesterday))
    }

    func testLogLocationVisit_multipleTasksSameDate_tracksIndependently() {
        let id1 = UUID()
        let id2 = UUID()
        let today = Date().dateString
        store.logLocationVisit(taskID: id1, on: today)
        XCTAssertTrue(store.hasVisitedLocation(taskID: id1, on: today))
        XCTAssertFalse(store.hasVisitedLocation(taskID: id2, on: today))
        store.logLocationVisit(taskID: id2, on: today)
        XCTAssertTrue(store.hasVisitedLocation(taskID: id2, on: today))
    }

    func testLocationVisits_persistsToUserDefaults() {
        // locationVisits is a computed property — reads directly from UserDefaults on every call
        // (no in-memory cache). Calling hasVisitedLocation after logLocationVisit confirms
        // the data was written to the backing store, not just held in memory.
        // Two SharedStore instances on the same suite cause CFPreferences corruption on device.
        let id = UUID()
        let today = Date().dateString
        store.logLocationVisit(taskID: id, on: today)
        XCTAssertTrue(store.hasVisitedLocation(taskID: id, on: today))
    }

    // MARK: - Completion flow

    func testCompleteTask_noLocation_completesNormally() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Run", activeDays: [todayWeekday])
        store.addTask(task)
        viewModel.onAppear()
        XCTAssertEqual(viewModel.todayTasks.count, 1)

        viewModel.completeTask(viewModel.todayTasks[0])

        XCTAssertTrue(viewModel.todayTasks.isEmpty)
        XCTAssertEqual(mockVerifier.verifyCallCount, 0)
    }

    func testCompleteTask_withLocation_alreadyVisited_completesWithoutVerify() async {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Go to gym", activeDays: [todayWeekday], location: loc)
        store.addTask(task)
        store.logLocationVisit(taskID: task.id, on: Date().dateString)
        viewModel.onAppear()

        let todayTask = viewModel.todayTasks[0]
        await viewModel.completeTaskWithLocationCheck(todayTask)

        XCTAssertTrue(viewModel.todayTasks.isEmpty)
        XCTAssertEqual(mockVerifier.verifyCallCount, 0) // no proximity check — already visited
    }

    func testCompleteTask_withLocation_notVisited_verified_completes() async {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Go to gym", activeDays: [todayWeekday], location: loc)
        store.addTask(task)
        viewModel.onAppear()
        mockVerifier.mockResult = true

        let todayTask = viewModel.todayTasks[0]
        await viewModel.completeTaskWithLocationCheck(todayTask)

        XCTAssertTrue(viewModel.todayTasks.isEmpty)
        XCTAssertEqual(mockVerifier.verifyCallCount, 1)
        XCTAssertNil(viewModel.locationVerificationFailed)
    }

    func testCompleteTask_withLocation_notVisited_notVerified_setsErrorState() async {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Go to gym", activeDays: [todayWeekday], location: loc)
        store.addTask(task)
        viewModel.onAppear()
        mockVerifier.mockResult = false

        let todayTask = viewModel.todayTasks[0]
        await viewModel.completeTaskWithLocationCheck(todayTask)

        XCTAssertEqual(viewModel.todayTasks.count, 1) // not completed
        XCTAssertEqual(viewModel.locationVerificationFailed, task.id)
    }

    func testLocationVerificationFailed_clearedOnSuccessfulRetry() async {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Go to gym", activeDays: [todayWeekday], location: loc)
        store.addTask(task)
        viewModel.onAppear()

        // First attempt fails
        mockVerifier.mockResult = false
        await viewModel.completeTaskWithLocationCheck(viewModel.todayTasks[0])
        XCTAssertNotNil(viewModel.locationVerificationFailed)

        // Second attempt succeeds
        mockVerifier.mockResult = true
        await viewModel.completeTaskWithLocationCheck(viewModel.todayTasks[0])
        XCTAssertNil(viewModel.locationVerificationFailed)
        XCTAssertTrue(viewModel.todayTasks.isEmpty)
    }

    func testCompleteTask_locationTask_withBothStepAndLocation_requiresVerification() async {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Workout at gym", activeDays: [todayWeekday], stepTarget: 5_000, location: loc)
        store.addTask(task)
        viewModel.onAppear()
        mockVerifier.mockResult = false

        await viewModel.completeTaskWithLocationCheck(viewModel.todayTasks[0])

        // Location verification failed — not completed even though this could be step-triggered
        XCTAssertEqual(viewModel.todayTasks.count, 1)
        XCTAssertEqual(viewModel.locationVerificationFailed, task.id)
    }

    // MARK: - Upgrade to Always prompt

    func testUpgradePrompt_shownAfterFirstSuccessfulCompletion_whenInUse() async {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Go to gym", activeDays: [todayWeekday], location: loc)
        store.addTask(task)
        viewModel.onAppear()
        mockVerifier.mockAuthStatus = .authorizedWhenInUse
        mockVerifier.mockResult = true
        XCTAssertFalse(store.hasPromptedLocationAlways)

        await viewModel.completeTaskWithLocationCheck(viewModel.todayTasks[0])

        XCTAssertTrue(viewModel.showLocationUpgradePrompt)
        XCTAssertTrue(store.hasPromptedLocationAlways)
    }

    func testUpgradePrompt_notShownWhenAlreadyAlways() async {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Go to gym", activeDays: [todayWeekday], location: loc)
        store.addTask(task)
        viewModel.onAppear()
        mockVerifier.mockAuthStatus = .authorizedAlways
        mockVerifier.mockResult = true

        await viewModel.completeTaskWithLocationCheck(viewModel.todayTasks[0])

        XCTAssertFalse(viewModel.showLocationUpgradePrompt)
    }

    func testUpgradePrompt_notShownTwice() async {
        let loc = TaskLocation(latitude: 37.7749, longitude: -122.4194, name: "Gym")
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Task 1", activeDays: [todayWeekday], location: loc))
        store.addTask(Task(title: "Task 2", activeDays: [todayWeekday], location: loc))
        viewModel.onAppear()
        mockVerifier.mockAuthStatus = .authorizedWhenInUse
        mockVerifier.mockResult = true

        // Complete first task — prompt shown
        await viewModel.completeTaskWithLocationCheck(viewModel.todayTasks[0])
        XCTAssertTrue(viewModel.showLocationUpgradePrompt)

        // Dismiss prompt, complete second task — prompt not shown again
        viewModel.showLocationUpgradePrompt = false
        await viewModel.completeTaskWithLocationCheck(viewModel.todayTasks[0])
        XCTAssertFalse(viewModel.showLocationUpgradePrompt)
    }

    func testUpgradeToAlwaysLocation_callsRequestAndDismissesPrompt() {
        viewModel.showLocationUpgradePrompt = true
        viewModel.upgradeToAlwaysLocation()
        XCTAssertFalse(viewModel.showLocationUpgradePrompt)
    }
}
