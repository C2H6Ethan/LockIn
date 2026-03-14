import XCTest
@testable import LockIn

final class ReminderNotificationTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.reminder.\(UUID().uuidString)")
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - dailyReminderTime defaults

    func testDailyReminderTime_defaultIs8pm() {
        let time = store.dailyReminderTime
        XCTAssertNotNil(time)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time!)
        XCTAssertEqual(comps.hour, 20)
        XCTAssertEqual(comps.minute, 0)
    }

    // MARK: - Never

    func testDailyReminderTime_setToNil_returnsNil() {
        store.dailyReminderTime = nil
        XCTAssertNil(store.dailyReminderTime)
    }

    func testDailyReminderTime_nilPersistsAcrossAccess() {
        store.dailyReminderTime = nil
        let _ = store.dailyReminderTime // access once
        XCTAssertNil(store.dailyReminderTime) // still nil
    }

    // MARK: - Custom times

    func testDailyReminderTime_persistsHourAndMinute() {
        var comps = DateComponents()
        comps.hour = 9
        comps.minute = 30
        let time = Calendar.current.date(from: comps)!
        store.dailyReminderTime = time

        let restored = store.dailyReminderTime
        XCTAssertNotNil(restored)
        let restoredComps = Calendar.current.dateComponents([.hour, .minute], from: restored!)
        XCTAssertEqual(restoredComps.hour, 9)
        XCTAssertEqual(restoredComps.minute, 30)
    }

    func testDailyReminderTime_persistsMidnightTime() {
        var comps = DateComponents()
        comps.hour = 0
        comps.minute = 0
        store.dailyReminderTime = Calendar.current.date(from: comps)!

        let restored = store.dailyReminderTime
        XCTAssertNotNil(restored)
        let restoredComps = Calendar.current.dateComponents([.hour, .minute], from: restored!)
        XCTAssertEqual(restoredComps.hour, 0)
        XCTAssertEqual(restoredComps.minute, 0)
    }

    func testDailyReminderTime_setNilThenSetTime_returnsNewTime() {
        store.dailyReminderTime = nil
        XCTAssertNil(store.dailyReminderTime)

        var comps = DateComponents()
        comps.hour = 18
        comps.minute = 0
        store.dailyReminderTime = Calendar.current.date(from: comps)!

        let result = store.dailyReminderTime
        XCTAssertNotNil(result)
        let resultComps = Calendar.current.dateComponents([.hour], from: result!)
        XCTAssertEqual(resultComps.hour, 18)
    }

    // MARK: - nextReminderTriggerDate

    func testNextReminderTrigger_beforeReminderTime_isToday() {
        // Reminder at 20:00, current time 14:00 → trigger today at 20:00
        let trigger = nextReminderTriggerDate(reminderHour: 20, reminderMinute: 0, now: makeTime(hour: 14, minute: 0))
        let comps = Calendar.current.dateComponents([.hour, .minute, .day], from: trigger)
        let nowComps = Calendar.current.dateComponents([.day], from: makeTime(hour: 14, minute: 0))
        XCTAssertEqual(comps.hour, 20)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.day, nowComps.day)
    }

    func testNextReminderTrigger_afterReminderTime_isTomorrow() {
        // Reminder at 20:00, current time 21:00 → trigger tomorrow at 20:00
        let now = makeTime(hour: 21, minute: 0)
        let trigger = nextReminderTriggerDate(reminderHour: 20, reminderMinute: 0, now: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let triggerComps = Calendar.current.dateComponents([.hour, .minute, .day, .month], from: trigger)
        let tomorrowComps = Calendar.current.dateComponents([.day, .month], from: tomorrow)
        XCTAssertEqual(triggerComps.hour, 20)
        XCTAssertEqual(triggerComps.minute, 0)
        XCTAssertEqual(triggerComps.day, tomorrowComps.day)
        XCTAssertEqual(triggerComps.month, tomorrowComps.month)
    }

    func testNextReminderTrigger_exactlyAtReminderTime_isTomorrow() {
        // Exactly at reminder time → already passed, schedule tomorrow
        let now = makeTime(hour: 20, minute: 0)
        let trigger = nextReminderTriggerDate(reminderHour: 20, reminderMinute: 0, now: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let triggerComps = Calendar.current.dateComponents([.day, .month], from: trigger)
        let tomorrowComps = Calendar.current.dateComponents([.day, .month], from: tomorrow)
        XCTAssertEqual(triggerComps.day, tomorrowComps.day)
        XCTAssertEqual(triggerComps.month, tomorrowComps.month)
    }

    func testNextReminderTrigger_minuteBefore_isToday() {
        let now = makeTime(hour: 19, minute: 59)
        let trigger = nextReminderTriggerDate(reminderHour: 20, reminderMinute: 0, now: now)
        let nowComps = Calendar.current.dateComponents([.day], from: now)
        let triggerComps = Calendar.current.dateComponents([.hour, .minute, .day], from: trigger)
        XCTAssertEqual(triggerComps.hour, 20)
        XCTAssertEqual(triggerComps.day, nowComps.day)
    }

    func testDailyReminderTime_overwriteExistingTime() {
        var comps = DateComponents()
        comps.hour = 7
        comps.minute = 0
        store.dailyReminderTime = Calendar.current.date(from: comps)!

        comps.hour = 21
        comps.minute = 15
        store.dailyReminderTime = Calendar.current.date(from: comps)!

        let result = store.dailyReminderTime
        XCTAssertNotNil(result)
        let resultComps = Calendar.current.dateComponents([.hour, .minute], from: result!)
        XCTAssertEqual(resultComps.hour, 21)
        XCTAssertEqual(resultComps.minute, 15)
    }

    // MARK: - Helpers

    private func makeTime(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 14
        comps.hour = hour; comps.minute = minute; comps.second = 0
        return Calendar.current.date(from: comps)!
    }
}
