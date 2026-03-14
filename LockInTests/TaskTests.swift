import XCTest
@testable import LockIn

final class TaskTests: XCTestCase {

    // MARK: - Task Codable

    func testTask_roundTrip() throws {
        let task = Task(title: "Run", activeDays: [2, 4], blocksApps: true)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)

        XCTAssertEqual(decoded.id, task.id)
        XCTAssertEqual(decoded.title, task.title)
        XCTAssertEqual(decoded.activeDays, task.activeDays)
        XCTAssertTrue(decoded.blocksApps)
    }

    func testTask_defaultBlocksApps_isTrue() {
        let task = Task(title: "Meditate", activeDays: [3])
        XCTAssertTrue(task.blocksApps)
    }

    func testTask_blocksApps_false_roundTrip() throws {
        let task = Task(title: "Floss", activeDays: [1, 2, 3, 4, 5, 6, 7], blocksApps: false)
        let data = try JSONEncoder().encode(task)
        let decoded = try JSONDecoder().decode(Task.self, from: data)
        XCTAssertFalse(decoded.blocksApps)
    }

    func testTask_uniqueIds() {
        let a = Task(title: "A", activeDays: [2])
        let b = Task(title: "B", activeDays: [3])
        XCTAssertNotEqual(a.id, b.id)
    }

    func testTask_activeDays_setPreservesUniqueness() {
        let task = Task(title: "A", activeDays: [2, 2, 4])
        XCTAssertEqual(task.activeDays.count, 2)
    }

    func testTaskArray_roundTrip() throws {
        let tasks = [
            Task(title: "Run", activeDays: [2, 4]),
            Task(title: "Read", activeDays: [1], blocksApps: false),
        ]
        let data = try JSONEncoder().encode(tasks)
        let decoded = try JSONDecoder().decode([Task].self, from: data)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].title, "Run")
        XCTAssertFalse(decoded[1].blocksApps)
    }

    // MARK: - TodayTask

    func testTodayTask_isCarryOver_false() {
        let task = TodayTask(id: UUID(), title: "Run", blocksApps: true, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString)
        XCTAssertFalse(task.isCarryOver)
        XCTAssertNil(task.originalDay)
    }

    func testTodayTask_isCarryOver_true_hasOriginalDay() {
        let task = TodayTask(id: UUID(), title: "Run", blocksApps: true, isCarryOver: true, originalDay: "Monday", scheduledDateString: "2026-03-09")
        XCTAssertTrue(task.isCarryOver)
        XCTAssertEqual(task.originalDay, "Monday")
    }

    func testTodayTask_nonBlocking() {
        let task = TodayTask(id: UUID(), title: "Floss", blocksApps: false, isCarryOver: false, originalDay: nil, scheduledDateString: Date().dateString)
        XCTAssertFalse(task.blocksApps)
    }

    func testTodayTask_scheduledDateString_storedCorrectly() {
        let task = TodayTask(id: UUID(), title: "Run", blocksApps: true, isCarryOver: true, originalDay: "Monday", scheduledDateString: "2026-03-09")
        XCTAssertEqual(task.scheduledDateString, "2026-03-09")
    }
}
