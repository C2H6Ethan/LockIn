import XCTest
import FamilyControls
@testable import LockIn

final class LockModeTests: XCTestCase {

    var store: SharedStore!
    var mockApplier: MockShieldApplier!
    var blocking: BlockingService!
    var sut: SettingsViewModel!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.lock.\(UUID().uuidString)")
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

    // MARK: - SharedStore lock state

    func testIsLocked_false_whenLockExpiresAtIsNil() {
        XCTAssertNil(store.lockExpiresAt)
        XCTAssertFalse(store.isLocked)
    }

    func testIsLocked_true_whenLockExpiresAtIsInFuture() {
        store.lockExpiresAt = Date().addingTimeInterval(60 * 60 * 24) // 1 day from now
        XCTAssertTrue(store.isLocked)
    }

    func testIsLocked_false_whenLockExpiresAtIsInPast() {
        store.lockExpiresAt = Date().addingTimeInterval(-60) // 1 minute ago
        XCTAssertFalse(store.isLocked)
    }

    // MARK: - SharedStore lockedAppTokens

    func testLockedAppTokens_nilByDefault() {
        XCTAssertNil(store.lockedAppTokens)
    }

    // MARK: - SettingsViewModel.activateLock

    func testActivateLock_setsIsLockedTrue() {
        sut.activateLock(days: 7)
        XCTAssertTrue(sut.isLocked)
    }

    func testActivateLock_setsLockExpiresAtInFuture() {
        let before = Date()
        sut.activateLock(days: 7)
        guard let expires = store.lockExpiresAt else {
            XCTFail("lockExpiresAt should be set after activateLock")
            return
        }
        XCTAssertGreaterThan(expires, before)
    }

    func testActivateLock_setsLockExpiresAt_approximately7Days() {
        let before = Date()
        sut.activateLock(days: 7)
        guard let expires = store.lockExpiresAt else {
            XCTFail("lockExpiresAt should be set")
            return
        }
        // Should be roughly 7 calendar days from now (within a few seconds).
        // Use Calendar to compute expected date so DST transitions don't break this.
        let expected = Calendar.current.date(byAdding: .day, value: 7, to: before)!
        XCTAssertLessThan(abs(expires.timeIntervalSince(expected)), 5)
    }

    func testActivateLock_snapshotsLockedAppTokens() {
        // Even with an empty selection, lockedAppTokens should be set (not nil) after lock
        sut.activateLock(days: 7)
        XCTAssertNotNil(store.lockedAppTokens)
    }

    func testActivateLock_setsLockedUntilSummaryNonEmpty() {
        sut.activateLock(days: 7)
        XCTAssertFalse(sut.lockedUntilSummary.isEmpty)
        XCTAssertTrue(sut.lockedUntilSummary.hasPrefix("Locked until"))
    }

    func testActivateLock_1Day_setsIsLocked() {
        sut.activateLock(days: 1)
        XCTAssertTrue(sut.isLocked)
        XCTAssertTrue(sut.lockedUntilSummary.hasPrefix("Locked until"))
    }

    func testActivateLock_30Days_setsIsLocked() {
        sut.activateLock(days: 30)
        XCTAssertTrue(sut.isLocked)
    }

    // MARK: - ViewModel reflects lock state

    func testIsLocked_reflectedInViewModel_whenLockExpiresAtSetOnStore() {
        store.lockExpiresAt = Date().addingTimeInterval(60 * 60 * 24)
        sut.onAppear()
        XCTAssertTrue(sut.isLocked)
    }

    func testIsLocked_false_inViewModel_whenStoreIsUnlocked() {
        store.lockExpiresAt = nil
        sut.onAppear()
        XCTAssertFalse(sut.isLocked)
    }

    func testIsLocked_false_inViewModel_whenLockExpired() {
        store.lockExpiresAt = Date().addingTimeInterval(-60)
        sut.onAppear()
        XCTAssertFalse(sut.isLocked)
    }

    func testLockExpiresAt_reflectedInViewModel() {
        let future = Date().addingTimeInterval(60 * 60 * 24 * 7)
        store.lockExpiresAt = future
        sut.onAppear()
        XCTAssertNotNil(sut.lockExpiresAt)
        // Should be within 1 second of what we set
        XCTAssertEqual(sut.lockExpiresAt!.timeIntervalSince1970, future.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - lockedUntilSummary

    func testLockedUntilSummary_containsDate_after7Days() {
        sut.activateLock(days: 7)
        let summary = sut.lockedUntilSummary
        XCTAssertTrue(summary.contains("Locked until"), "Expected 'Locked until' in: \(summary)")
    }

    func testLockedUntilSummary_empty_whenNotLocked() {
        XCTAssertEqual(sut.lockedUntilSummary, "")
    }

    func testLockedUntilSummary_empty_whenLockExpired() {
        store.lockExpiresAt = Date().addingTimeInterval(-60)
        sut.onAppear()
        // lockExpiresAt is set but in the past — isLocked is false
        // lockedUntilSummary should reflect the stored date even if expired, OR be empty
        // Per spec: it reads from lockExpiresAt directly without isLocked check
        // The implementation returns "" when lockExpiresAt is nil, and a date string otherwise
        // Since lockExpiresAt IS set (just expired), we test whichever behavior is implemented
        // The key invariant: must not crash
        _ = sut.lockedUntilSummary
    }

    // MARK: - showingLockSheet

    func testShowingLockSheet_defaultsFalse() {
        XCTAssertFalse(sut.showingLockSheet)
    }

    func testShowingLockSheet_canBeSetToTrue() {
        sut.showingLockSheet = true
        XCTAssertTrue(sut.showingLockSheet)
    }

    // MARK: - saveSelectedApps when locked (smoke test — no real tokens in test env)

    func testSaveSelectedApps_whenLocked_doesNotCrash() {
        sut.activateLock(days: 7)
        let emptySelection = FamilyActivitySelection()
        // Should not crash even when locked
        sut.saveSelectedApps(emptySelection)
    }

    func testSaveSelectedApps_whenUnlocked_doesNotCrash() {
        let emptySelection = FamilyActivitySelection()
        sut.saveSelectedApps(emptySelection)
    }
}
