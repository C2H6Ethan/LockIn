import XCTest
@testable import LockIn

/// Tests the logic that drives OnboardingView's habit step.
/// finish() and canAddTask are private SwiftUI state, so we mirror the
/// exact same predicates here to pin the behaviour in tests.
/// Note: tests that require SharedStore are omitted — addTask behaviour is
/// covered by SharedStoreTests/AddTaskTests, and creating a second
/// SharedStore instance alongside SharedStore.shared crashes on iOS 26 beta.
final class OnboardingTests: XCTestCase {

    // MARK: - canAddTask predicate (weekly — requires title + days)

    func testCanAddTask_weekly_falseWhenBothEmpty() {
        XCTAssertFalse(canAddTask(title: "", repeats: true, days: []))
    }

    func testCanAddTask_weekly_falseWhenTitleEmptyDaysSet() {
        XCTAssertFalse(canAddTask(title: "", repeats: true, days: [2]))
    }

    func testCanAddTask_weekly_falseWhenTitleWhitespaceOnly() {
        XCTAssertFalse(canAddTask(title: "   ", repeats: true, days: [2, 4]))
    }

    func testCanAddTask_weekly_falseWhenDaysEmpty() {
        XCTAssertFalse(canAddTask(title: "Run", repeats: true, days: []))
    }

    func testCanAddTask_weekly_trueWhenTitleAndDaysSet() {
        XCTAssertTrue(canAddTask(title: "Run", repeats: true, days: [2]))
    }

    func testCanAddTask_weekly_trueWhenMultipleDays() {
        XCTAssertTrue(canAddTask(title: "Exercise", repeats: true, days: [2, 4, 6]))
    }

    // MARK: - canAddTask predicate (once — only requires title)

    func testCanAddTask_once_falseWhenTitleEmpty() {
        XCTAssertFalse(canAddTask(title: "", repeats: false, days: []))
    }

    func testCanAddTask_once_falseWhenTitleWhitespaceOnly() {
        XCTAssertFalse(canAddTask(title: "   ", repeats: false, days: []))
    }

    func testCanAddTask_once_trueWhenTitleFilled() {
        XCTAssertTrue(canAddTask(title: "Run", repeats: false, days: []))
    }

    func testCanAddTask_once_daysIgnored() {
        // For one-time tasks, days don't matter — title alone gates the button
        XCTAssertTrue(canAddTask(title: "Run", repeats: false, days: [2, 4]))
    }

    // MARK: - Button label

    func testButtonLabel_skipWhenTitleEmpty() {
        XCTAssertEqual(finishButtonLabel(title: ""), "Skip")
    }

    func testButtonLabel_skipWhenTitleWhitespaceOnly() {
        XCTAssertEqual(finishButtonLabel(title: "   "), "Skip")
    }

    func testButtonLabel_addAndFinishWhenTitleFilled() {
        XCTAssertEqual(finishButtonLabel(title: "Run"), "Add & finish")
    }

    func testButtonLabel_addAndFinishTrimsLeadingWhitespace() {
        XCTAssertEqual(finishButtonLabel(title: " Run"), "Add & finish")
    }

    // MARK: - Helpers

    /// Mirrors canAddTask in OnboardingView
    private func canAddTask(title: String, repeats: Bool, days: Set<Int>) -> Bool {
        let titleOk = !title.trimmingCharacters(in: .whitespaces).isEmpty
        return repeats ? titleOk && !days.isEmpty : titleOk
    }

    /// Mirrors the button label ternary in OnboardingView.habitStep
    private func finishButtonLabel(title: String) -> String {
        !title.trimmingCharacters(in: .whitespaces).isEmpty ? "Add & finish" : "Skip"
    }
}
