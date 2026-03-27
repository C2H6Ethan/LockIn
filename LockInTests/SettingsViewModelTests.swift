import XCTest
@testable import LockIn

final class SettingsViewModelTests: XCTestCase {

    var store: SharedStore!
    var mockApplier: MockShieldApplier!
    var blocking: BlockingService!
    var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.settings.\(UUID().uuidString)")
        mockApplier = MockShieldApplier()
        blocking = BlockingService(store: store, applier: mockApplier)
        sut = SettingsViewModel(store: store, blocking: blocking)
    }

    override func tearDown() {
        sut = nil
        blocking = nil
        mockApplier = nil
        store = nil
        super.tearDown()
    }

    // MARK: - selectedAppsCount + appSelectionSummary

    func testSelectedCount_defaultsToZero() {
        XCTAssertEqual(sut.selectedCount, 0)
    }

    func testAppSelectionSummary_noApps_returnsNone() {
        XCTAssertEqual(sut.appSelectionSummary, "None")
    }

    // MARK: - tasks

    func testInitialState_tasksEmpty() {
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    func testOnAppear_loadsTasks() {
        let task = Task(title: "Morning Run", activeDays: [2, 3, 4], blocksApps: true)
        store.addTask(task)

        sut.onAppear()

        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertEqual(sut.tasks[0].title, "Morning Run")
    }

    func testOnAppear_loadsMultipleTasks() {
        store.addTask(Task(title: "Run", activeDays: [2], blocksApps: true))
        store.addTask(Task(title: "Meditate", activeDays: [3], blocksApps: false))
        store.addTask(Task(title: "Floss", activeDays: [1, 2, 3, 4, 5, 6, 7], blocksApps: false))

        sut.onAppear()

        XCTAssertEqual(sut.tasks.count, 3)
    }

    // MARK: - deleteTask

    func testDeleteTask_removesFromList() {
        let task = Task(title: "Morning Run", activeDays: [2], blocksApps: true)
        store.addTask(task)
        sut.onAppear()
        XCTAssertEqual(sut.tasks.count, 1)

        sut.deleteTask(id: task.id)

        XCTAssertTrue(sut.tasks.isEmpty)
    }

    func testDeleteTask_removesFromStore() {
        let task = Task(title: "Morning Run", activeDays: [2], blocksApps: true)
        store.addTask(task)
        sut.onAppear()

        sut.deleteTask(id: task.id)

        XCTAssertTrue(store.tasks.isEmpty)
    }

    func testDeleteTask_withMultipleTasks_removesCorrectOne() {
        let task1 = Task(title: "Run", activeDays: [2], blocksApps: true)
        let task2 = Task(title: "Meditate", activeDays: [3], blocksApps: false)
        store.addTask(task1)
        store.addTask(task2)
        sut.onAppear()

        sut.deleteTask(id: task1.id)

        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertEqual(sut.tasks[0].title, "Meditate")
    }

    func testDeleteTask_postsHabitsDidChangeNotification() {
        let task = Task(title: "Morning Run", activeDays: [2], blocksApps: true)
        store.addTask(task)
        sut.onAppear()

        let expectation = XCTestExpectation(description: "habitsDidChange posted on delete")
        let observer = NotificationCenter.default.addObserver(
            forName: .habitsDidChange,
            object: nil,
            queue: .main
        ) { _ in expectation.fulfill() }

        sut.deleteTask(id: task.id)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testDeleteTask_nonExistentId_doesNotCrash() {
        sut.onAppear()
        let randomId = UUID()
        // Should not crash
        sut.deleteTask(id: randomId)
        XCTAssertTrue(sut.tasks.isEmpty)
    }

    // MARK: - updateTask

    func testUpdateTask_updatesInList() {
        let task = Task(title: "Morning Run", activeDays: [2], blocksApps: true)
        store.addTask(task)
        sut.onAppear()

        let updated = Task(id: task.id, title: "Evening Run", activeDays: [3, 4], blocksApps: false, createdAt: task.createdAt)
        sut.updateTask(updated)

        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertEqual(sut.tasks[0].title, "Evening Run")
        XCTAssertEqual(sut.tasks[0].activeDays, [3, 4])
        XCTAssertFalse(sut.tasks[0].blocksApps)
    }

    func testUpdateTask_persistsToStore() {
        let task = Task(title: "Morning Run", activeDays: [2], blocksApps: true)
        store.addTask(task)
        sut.onAppear()

        let updated = Task(id: task.id, title: "Evening Run", activeDays: [5], blocksApps: false, createdAt: task.createdAt)
        sut.updateTask(updated)

        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].title, "Evening Run")
    }

    func testUpdateTask_postsHabitsDidChangeNotification() {
        let task = Task(title: "Morning Run", activeDays: [2], blocksApps: true)
        store.addTask(task)
        sut.onAppear()

        let expectation = XCTestExpectation(description: "habitsDidChange posted on update")
        let observer = NotificationCenter.default.addObserver(
            forName: .habitsDidChange,
            object: nil,
            queue: .main
        ) { _ in expectation.fulfill() }

        let updated = Task(id: task.id, title: "Evening Run", activeDays: [3], blocksApps: true, createdAt: task.createdAt)
        sut.updateTask(updated)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testUpdateTask_preservesId() {
        let task = Task(title: "Morning Run", activeDays: [2], blocksApps: true)
        store.addTask(task)
        sut.onAppear()

        let updated = Task(id: task.id, title: "Evening Run", activeDays: [3], blocksApps: false, createdAt: task.createdAt)
        sut.updateTask(updated)

        XCTAssertEqual(sut.tasks[0].id, task.id)
    }

    // MARK: - Task sorting

    func testTasks_sortedByEarliestWeekday() {
        // Wed task should come after Mon task
        store.addTask(Task(title: "Yoga", activeDays: [4]))      // Wed
        store.addTask(Task(title: "Run", activeDays: [2]))        // Mon
        sut.onAppear()

        XCTAssertEqual(sut.tasks[0].title, "Run")
        XCTAssertEqual(sut.tasks[1].title, "Yoga")
    }

    func testTasks_sameEarliestWeekday_sortedAlphabetically() {
        store.addTask(Task(title: "Yoga", activeDays: [2]))
        store.addTask(Task(title: "Meditate", activeDays: [2]))
        store.addTask(Task(title: "Run", activeDays: [2]))
        sut.onAppear()

        XCTAssertEqual(sut.tasks[0].title, "Meditate")
        XCTAssertEqual(sut.tasks[1].title, "Run")
        XCTAssertEqual(sut.tasks[2].title, "Yoga")
    }

    func testTasks_multipleDays_usesEarliestDay() {
        // Task has Wed+Fri — earliest is Wed (index 2 in Mon-Sun order)
        // Other task has Thu only (index 3)
        store.addTask(Task(title: "Thu Task", activeDays: [5]))       // Thu
        store.addTask(Task(title: "Wed+Fri Task", activeDays: [4, 6])) // Wed, Fri
        sut.onAppear()

        XCTAssertEqual(sut.tasks[0].title, "Wed+Fri Task")
        XCTAssertEqual(sut.tasks[1].title, "Thu Task")
    }

    func testTasks_sundayComesAfterSaturday() {
        store.addTask(Task(title: "Sunday Task", activeDays: [1]))  // Sun
        store.addTask(Task(title: "Saturday Task", activeDays: [7])) // Sat
        sut.onAppear()

        XCTAssertEqual(sut.tasks[0].title, "Saturday Task")
        XCTAssertEqual(sut.tasks[1].title, "Sunday Task")
    }

    // MARK: - showingAddTask

    func testShowingAddTask_defaultsFalse() {
        XCTAssertFalse(sut.showingAddTask)
    }

    func testShowingAddTask_canBeSetToTrue() {
        sut.showingAddTask = true
        XCTAssertTrue(sut.showingAddTask)
    }

    // MARK: - Notification-driven sync

    // MARK: - Custom domain management

    func testAddCustomDomain_addsToStore() {
        sut.addCustomDomain("reddit.com")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testAddCustomDomain_updatesViewModel() {
        sut.addCustomDomain("reddit.com")
        XCTAssertEqual(sut.customDomains, ["reddit.com"])
    }

    func testAddCustomDomain_stripsHttps() {
        sut.addCustomDomain("https://reddit.com")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testAddCustomDomain_stripsHttp() {
        sut.addCustomDomain("http://reddit.com")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testAddCustomDomain_stripsWwwPrefix() {
        sut.addCustomDomain("www.reddit.com")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testAddCustomDomain_stripsHttpsAndWww() {
        sut.addCustomDomain("https://www.reddit.com")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testAddCustomDomain_wwwMidDomain_notCorrupted() {
        // "awesome-www.io" should not be mangled — www. only stripped as a prefix
        sut.addCustomDomain("awesome-www.io")
        XCTAssertEqual(store.selectedWebDomains, ["awesome-www.io"])
    }

    func testAddCustomDomain_stripsPathComponent() {
        sut.addCustomDomain("reddit.com/r/programming")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testAddCustomDomain_stripsFullUrlWithPath() {
        sut.addCustomDomain("https://www.reddit.com/r/programming")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testAddCustomDomain_lowercases() {
        sut.addCustomDomain("Reddit.COM")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testAddCustomDomain_deduplicates() {
        sut.addCustomDomain("reddit.com")
        sut.addCustomDomain("reddit.com")
        XCTAssertEqual(store.selectedWebDomains.count, 1)
    }

    func testAddCustomDomain_emptyString_ignored() {
        sut.addCustomDomain("")
        XCTAssertTrue(store.selectedWebDomains.isEmpty)
    }

    func testAddCustomDomain_whitespaceOnly_ignored() {
        sut.addCustomDomain("   ")
        XCTAssertTrue(store.selectedWebDomains.isEmpty)
    }

    func testAddCustomDomain_enforcesLimit() {
        for i in 0..<50 {
            sut.addCustomDomain("domain\(i).com")
        }
        sut.addCustomDomain("overflow.com")
        XCTAssertEqual(store.selectedWebDomains.count, 50)
        XCTAssertFalse(store.selectedWebDomains.contains("overflow.com"))
    }

    func testAddCustomDomain_triggersBlocking() {
        let today = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Exercise", activeDays: [today], blocksApps: true))
        sut.addCustomDomain("reddit.com")
        XCTAssertEqual(mockApplier.applyCallCount, 1)
    }

    func testRemoveCustomDomain_removesFromStore() {
        store.selectedWebDomains = ["reddit.com", "youtube.com"]
        sut.onAppear()
        sut.removeCustomDomain("reddit.com")
        XCTAssertEqual(store.selectedWebDomains, ["youtube.com"])
    }

    func testRemoveCustomDomain_updatesViewModel() {
        store.selectedWebDomains = ["reddit.com", "youtube.com"]
        sut.onAppear()
        sut.removeCustomDomain("reddit.com")
        XCTAssertEqual(sut.customDomains, ["youtube.com"])
    }

    func testRemoveCustomDomain_whileLocked_ignored() {
        store.selectedWebDomains = ["reddit.com"]
        store.lockExpiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        sut.onAppear()
        sut.removeCustomDomain("reddit.com")
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testClearCustomDomains_clearsAll() {
        store.selectedWebDomains = ["reddit.com", "youtube.com"]
        sut.onAppear()
        sut.clearCustomDomains()
        XCTAssertTrue(store.selectedWebDomains.isEmpty)
        XCTAssertTrue(sut.customDomains.isEmpty)
    }

    func testClearCustomDomains_clearsLockedSnapshot() {
        store.selectedWebDomains = ["reddit.com"]
        store.lockedWebDomains = ["reddit.com"]
        sut.clearCustomDomains()
        XCTAssertNil(store.lockedWebDomains)
    }

    func testClearCustomDomains_whileLocked_ignored() {
        store.selectedWebDomains = ["reddit.com"]
        store.lockExpiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        sut.onAppear()
        sut.clearCustomDomains()
        XCTAssertEqual(store.selectedWebDomains, ["reddit.com"])
    }

    func testCustomDomainSummary_empty_returnsNone() {
        XCTAssertEqual(sut.customDomainSummary, "None")
    }

    func testCustomDomainSummary_one_returnsSingular() {
        sut.addCustomDomain("reddit.com")
        XCTAssertEqual(sut.customDomainSummary, "1 domain")
    }

    func testCustomDomainSummary_many_returnsPlural() {
        sut.addCustomDomain("reddit.com")
        sut.addCustomDomain("youtube.com")
        XCTAssertEqual(sut.customDomainSummary, "2 domains")
    }

    func testActivateLock_snapshotsCustomDomains() {
        store.selectedWebDomains = ["reddit.com", "youtube.com"]
        sut.activateLock(days: 3)
        XCTAssertEqual(store.lockedWebDomains, ["reddit.com", "youtube.com"])
    }

    func testAddCustomDomain_whileLocked_snapshotsUpdated() {
        store.selectedWebDomains = ["reddit.com"]
        store.lockedWebDomains = ["reddit.com"]
        store.lockExpiresAt = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        sut.onAppear()
        sut.addCustomDomain("youtube.com")
        XCTAssertEqual(store.lockedWebDomains?.sorted(), ["reddit.com", "youtube.com"].sorted())
    }

    func testHabitsDidChange_notification_reloadsTasks() async {
        sut.onAppear()
        XCTAssertTrue(sut.tasks.isEmpty)

        // Simulate another component (e.g. TodayViewModel) adding a task and posting
        store.addTask(Task(title: "External Task", activeDays: [2], blocksApps: true))

        let expectation = XCTestExpectation(description: "tasks list updated after notification")
        NotificationCenter.default.post(name: .habitsDidChange, object: nil)

        // Give the main queue a moment to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(sut.tasks.count, 1)
        XCTAssertEqual(sut.tasks[0].title, "External Task")
    }
}
