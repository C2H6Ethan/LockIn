import XCTest
@testable import LockIn

final class ReviewManagerTests: XCTestCase {

    var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.review.\(UUID().uuidString)")
    }

    override func tearDown() {
        defaults = nil
        super.tearDown()
    }

    // MARK: - Eligibility

    func testStreakBelow7_doesNotRequest() {
        var called = false
        ReviewManager.requestIfEligible(currentStreak: 6, defaults: defaults) { called = true }
        XCTAssertFalse(called)
    }

    func testStreak7_requests() {
        var called = false
        ReviewManager.requestIfEligible(currentStreak: 7, defaults: defaults) { called = true }
        XCTAssertTrue(called)
    }

    func testStreakAbove7_doesNotRequest() {
        var called = false
        ReviewManager.requestIfEligible(currentStreak: 14, defaults: defaults) { called = true }
        XCTAssertFalse(called)
    }

    // MARK: - One-time flag

    func testStreak7_setsFlag() {
        ReviewManager.requestIfEligible(currentStreak: 7, defaults: defaults) {}
        XCTAssertTrue(defaults.bool(forKey: ReviewManager.flagKey))
    }

    func testStreak7_secondCall_doesNotRequestAgain() {
        var callCount = 0
        ReviewManager.requestIfEligible(currentStreak: 7, defaults: defaults) { callCount += 1 }
        ReviewManager.requestIfEligible(currentStreak: 7, defaults: defaults) { callCount += 1 }
        XCTAssertEqual(callCount, 1)
    }

    func testFlagAlreadySet_doesNotRequest() {
        defaults.set(true, forKey: ReviewManager.flagKey)
        var called = false
        ReviewManager.requestIfEligible(currentStreak: 7, defaults: defaults) { called = true }
        XCTAssertFalse(called)
    }

    // MARK: - Flag not set for non-7 streaks

    func testStreakBelow7_doesNotSetFlag() {
        ReviewManager.requestIfEligible(currentStreak: 6, defaults: defaults) {}
        XCTAssertFalse(defaults.bool(forKey: ReviewManager.flagKey))
    }

    func testStreakAbove7_doesNotSetFlag() {
        ReviewManager.requestIfEligible(currentStreak: 8, defaults: defaults) {}
        XCTAssertFalse(defaults.bool(forKey: ReviewManager.flagKey))
    }
}
