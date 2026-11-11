import Foundation
import Testing
@testable import LockInCore

struct DayKeyTests {
    @Test func parsesAndFormats() {
        #expect(DayKey("2026-11-09")?.description == "2026-11-09")
        #expect(DayKey("2026-02-30") == nil)
        #expect(DayKey("nonsense") == nil)
    }

    @Test func derivesFromInstantInCalendarTimeZone() {
        // 23:30 in Zurich is already the next Day in Tokyo.
        let date = instant("2026-11-09", 23, 30, in: calendar("Europe/Zurich"))
        #expect(DayKey(date, calendar: calendar("Europe/Zurich")) == day("2026-11-09"))
        #expect(DayKey(date, calendar: calendar("Asia/Tokyo")) == day("2026-11-10"))
    }

    @Test func weekday() {
        #expect(day("2026-11-09").weekday(in: calendar()) == .monday)
        #expect(day("2026-11-15").weekday(in: calendar()) == .sunday)
    }

    @Test(arguments: [("Europe/Zurich", "2026-03-29"), ("Europe/Zurich", "2026-10-25"), ("America/New_York", "2026-03-08")])
    func weekdayIsCorrectOnDSTChangeDays(tz: String, dayString: String) {
        #expect(day(dayString).weekday(in: calendar(tz)) == .sunday)
    }

    @Test func addingDaysAcrossMonthAndDST() {
        #expect(day("2026-10-31").adding(days: 1, in: calendar()) == day("2026-11-01"))
        #expect(day("2026-03-28").adding(days: 2, in: calendar()) == day("2026-03-30"))
        #expect(day("2026-03-01").adding(days: -1, in: calendar()) == day("2026-02-28"))
    }

    @Test func ordersChronologically() {
        #expect(day("2025-12-31") < day("2026-01-01"))
        #expect(day("2026-01-09") < day("2026-01-10"))
    }

    @Test func codesAsStringAndAsDictionaryKey() throws {
        let encoded = try JSONEncoder().encode([day("2026-11-09"): 1])
        #expect(String(decoding: encoded, as: UTF8.self) == #"{"2026-11-09":1}"#)
        let decoded = try JSONDecoder().decode([DayKey: Int].self, from: encoded)
        #expect(decoded == [day("2026-11-09"): 1])
    }
}
