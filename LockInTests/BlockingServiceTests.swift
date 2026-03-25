import XCTest
import FamilyControls
@testable import LockIn

// MARK: - Mock

final class MockShieldApplier: ShieldApplying {
    private(set) var applyCallCount = 0
    private(set) var removeCallCount = 0

    func apply(selection: FamilyActivitySelection) { applyCallCount += 1 }
    func remove() { removeCallCount += 1 }
}

// MARK: - Tests

final class BlockingServiceTests: XCTestCase {

    var store: SharedStore!
    var mockApplier: MockShieldApplier!
    var sut: BlockingService!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.blocking.\(UUID().uuidString)")
        mockApplier = MockShieldApplier()
        sut = BlockingService(store: store, applier: mockApplier)
    }

    override func tearDown() {
        sut = nil
        mockApplier = nil
        store = nil
        super.tearDown()
    }

    // MARK: - updateShieldsForCurrentHabitState

    func testUpdateShields_noTasks_removesShields() {
        sut.updateShieldsForCurrentHabitState()
        XCTAssertEqual(mockApplier.removeCallCount, 1)
        XCTAssertEqual(mockApplier.applyCallCount, 0)
    }

    func testUpdateShields_allTasksComplete_removesShields() {
        let today = Calendar.current.component(.weekday, from: Date())
        let task = Task(title: "Exercise", activeDays: [today])
        store.addTask(task)
        store.completeTask(task.id, on: Date().dateString)

        sut.updateShieldsForCurrentHabitState()

        XCTAssertEqual(mockApplier.removeCallCount, 1)
        XCTAssertEqual(mockApplier.applyCallCount, 0)
    }

    func testUpdateShields_incompleteBlockingTask_noAppsSelected_removesShields() {
        let today = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Exercise", activeDays: [today]))
        // selectedApps is empty FamilyActivitySelection() by default

        sut.updateShieldsForCurrentHabitState()

        XCTAssertEqual(mockApplier.removeCallCount, 1)
        XCTAssertEqual(mockApplier.applyCallCount, 0)
    }

    func testUpdateShields_activeUnblockWindow_noOp() {
        store.unblockExpiresAt = Date().addingTimeInterval(60)

        sut.updateShieldsForCurrentHabitState()

        // Shields stay removed during bypass — no-op
        XCTAssertEqual(mockApplier.removeCallCount, 0)
        XCTAssertEqual(mockApplier.applyCallCount, 0)
    }

    func testUpdateShields_expiredUnblockWindow_clearsExpiryAndRemoves() {
        store.unblockExpiresAt = Date().addingTimeInterval(-1)

        sut.updateShieldsForCurrentHabitState()

        XCTAssertNil(store.unblockExpiresAt)
        XCTAssertEqual(mockApplier.removeCallCount, 1)
    }

    func testUpdateShields_nonBlockingTask_noApps_removesShields() {
        let today = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Floss", activeDays: [today], blocksApps: false))

        sut.updateShieldsForCurrentHabitState()

        XCTAssertEqual(mockApplier.removeCallCount, 1)
        XCTAssertEqual(mockApplier.applyCallCount, 0)
    }

    // MARK: - temporaryUnblock

    func testTemporaryUnblock_removesShields() {
        sut.temporaryUnblock(duration: 60)
        XCTAssertEqual(mockApplier.removeCallCount, 1)
    }

    func testTemporaryUnblock_storesExpiryDate() {
        let before = Date()
        sut.temporaryUnblock(duration: 60)

        guard let expires = store.unblockExpiresAt else {
            XCTFail("unblockExpiresAt should be set")
            return
        }
        XCTAssertGreaterThan(expires, before.addingTimeInterval(59))
        XCTAssertLessThanOrEqual(expires, Date().addingTimeInterval(61))
    }

    func testTemporaryUnblock_calledTwice_removeCalledTwice() {
        sut.temporaryUnblock(duration: 60)
        sut.temporaryUnblock(duration: 60)
        XCTAssertEqual(mockApplier.removeCallCount, 2)
    }

    func testTemporaryUnblock_expiryIsInFuture() {
        sut.temporaryUnblock(duration: 10)
        XCTAssertNotNil(store.unblockExpiresAt)
        XCTAssertGreaterThan(store.unblockExpiresAt!, Date())
    }

    // MARK: - updateShields idempotency

    func testUpdateShields_calledTwice_removesEachTime() {
        sut.updateShieldsForCurrentHabitState()
        sut.updateShieldsForCurrentHabitState()
        XCTAssertEqual(mockApplier.removeCallCount, 2)
    }

    func testUpdateShields_incompleteTasksWithActiveUnblock_noOp() {
        let today = Calendar.current.component(.weekday, from: Date())
        store.addTask(Task(title: "Exercise", activeDays: [today]))
        store.unblockExpiresAt = Date().addingTimeInterval(30)

        sut.updateShieldsForCurrentHabitState()

        // No-op during active bypass
        XCTAssertEqual(mockApplier.applyCallCount, 0)
        XCTAssertEqual(mockApplier.removeCallCount, 0)
    }

    func testUpdateShields_afterExpiredUnblock_clearsExpiryEachTime() {
        store.unblockExpiresAt = Date().addingTimeInterval(-5)
        sut.updateShieldsForCurrentHabitState()
        XCTAssertNil(store.unblockExpiresAt)

        sut.updateShieldsForCurrentHabitState()
        XCTAssertEqual(mockApplier.removeCallCount, 2)
    }
}
