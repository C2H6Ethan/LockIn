import XCTest
@testable import LockIn

final class ShieldConfigurationHelperTests: XCTestCase {

    // MARK: - subtitleText
    // Note: result format is "header\n• Task1\n• Task2" where header is random

    func testSubtitleText_empty_returnsEmpty() {
        XCTAssertEqual(Constants.ShieldDisplay.subtitleText(for: []), "")
    }

    func testSubtitleText_oneTask_containsBulletAndTitle() {
        let task = TodayTask(id: UUID(), title: "Run 5k", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString)
        let result = Constants.ShieldDisplay.subtitleText(for: [task])
        XCTAssertTrue(result.contains("• Run 5k"))
    }

    func testSubtitleText_twoTasks_containsBothTitles() {
        let tasks = [
            TodayTask(id: UUID(), title: "Run 5k", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString),
            TodayTask(id: UUID(), title: "Read", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString),
        ]
        let result = Constants.ShieldDisplay.subtitleText(for: tasks)
        XCTAssertTrue(result.contains("• Run 5k"))
        XCTAssertTrue(result.contains("• Read"))
    }

    func testSubtitleText_fourTasks_capped_atThree() {
        let tasks = (1...4).map {
            TodayTask(id: UUID(), title: "Task \($0)", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString)
        }
        let result = Constants.ShieldDisplay.subtitleText(for: tasks)
        XCTAssertFalse(result.contains("Task 4"))
        XCTAssertTrue(result.contains("Task 1"))
        XCTAssertTrue(result.contains("Task 3"))
    }

    func testSubtitleText_taskLinesStartWithBullet() {
        let tasks = [
            TodayTask(id: UUID(), title: "A", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString),
            TodayTask(id: UUID(), title: "B", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString),
        ]
        let result = Constants.ShieldDisplay.subtitleText(for: tasks)
        let taskLines = result.components(separatedBy: "\n").filter { $0.hasPrefix("• ") }
        XCTAssertEqual(taskLines.count, 2)
    }

    func testSubtitleText_exactlyThreeTasks_allIncluded() {
        let tasks = (1...3).map {
            TodayTask(id: UUID(), title: "Task \($0)", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString)
        }
        let result = Constants.ShieldDisplay.subtitleText(for: tasks)
        XCTAssertTrue(result.contains("Task 1"))
        XCTAssertTrue(result.contains("Task 2"))
        XCTAssertTrue(result.contains("Task 3"))
    }

    func testSubtitleText_preservesTaskTitleExactly() {
        let title = "Read 30 minutes every day"
        let task = TodayTask(id: UUID(), title: title, blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString)
        let result = Constants.ShieldDisplay.subtitleText(for: [task])
        XCTAssertTrue(result.contains(title))
    }

    func testSubtitleText_nonEmpty_hasHeaderLine() {
        let task = TodayTask(id: UUID(), title: "X", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString)
        let result = Constants.ShieldDisplay.subtitleText(for: [task])
        let lines = result.components(separatedBy: "\n")
        XCTAssertGreaterThanOrEqual(lines.count, 2)
        XCTAssertFalse(lines[0].hasPrefix("•"))
    }

    // MARK: - ShieldDisplay constants

    func testShieldDisplayPrimaryButton_nonEmpty() {
        XCTAssertFalse(Constants.ShieldDisplay.primaryButton.isEmpty)
    }
}
