import XCTest
@testable import LockIn

final class DateHelperTests: XCTestCase {

    // MARK: - dateString

    func testDateString_format_isISO() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!
        XCTAssertEqual(date.dateString, "2026-01-15")
    }

    func testDateString_singleDigitMonth_padded() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 5
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!
        XCTAssertEqual(date.dateString, "2026-03-05")
    }

    func testDateString_today_matchesLocalTimezone() {
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        XCTAssertEqual(today.dateString, formatter.string(from: today))
    }

    func testDateString_localMidnight_isCorrectDate() {
        // 11:30pm local time should produce today's date string, not tomorrow's
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 3
        comps.day = 14
        comps.hour = 23
        comps.minute = 30
        comps.timeZone = .current
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(date.dateString, "2026-03-14")
    }

    func testFromDateString_roundTrips() {
        let original = "2026-06-15"
        let date = Date.from(dateString: original)!
        XCTAssertEqual(date.dateString, original)
    }

    // MARK: - weekdayName

    func testWeekdayName_sunday() {
        XCTAssertEqual(makeDate(weekday: 1).weekdayName, "Sunday")
    }

    func testWeekdayName_monday() {
        XCTAssertEqual(makeDate(weekday: 2).weekdayName, "Monday")
    }

    func testWeekdayName_wednesday() {
        XCTAssertEqual(makeDate(weekday: 4).weekdayName, "Wednesday")
    }

    func testWeekdayName_saturday() {
        XCTAssertEqual(makeDate(weekday: 7).weekdayName, "Saturday")
    }

    // MARK: - weekday

    func testWeekday_matchesCalendar() {
        let today = Date()
        XCTAssertEqual(today.weekday, Calendar.current.component(.weekday, from: today))
    }

    func testWeekday_monday() {
        XCTAssertEqual(makeDate(weekday: 2).weekday, 2)
    }

    func testWeekday_friday() {
        XCTAssertEqual(makeDate(weekday: 6).weekday, 6)
    }

    // MARK: - previousDays

    func testPreviousDays_count3_returns3Dates() {
        XCTAssertEqual(Date().previousDays(count: 3).count, 3)
    }

    func testPreviousDays_count0_returnsEmpty() {
        XCTAssertTrue(Date().previousDays(count: 0).isEmpty)
    }

    func testPreviousDays_firstIsYesterday() {
        let days = Date().previousDays(count: 3)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(days[0].dateString, yesterday.dateString)
    }

    func testPreviousDays_secondIsTwoDaysAgo() {
        let days = Date().previousDays(count: 3)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertEqual(days[1].dateString, twoDaysAgo.dateString)
    }

    func testPreviousDays_count7_lastIsSevenDaysAgo() {
        let days = Date().previousDays(count: 7)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        XCTAssertEqual(days[6].dateString, sevenDaysAgo.dateString)
    }

    // MARK: - Helpers

    private func makeDate(weekday: Int) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let now = Date()
        let currentWeek = cal.component(.weekOfYear, from: now)
        let currentYear = cal.component(.yearForWeekOfYear, from: now)
        var components = DateComponents()
        components.weekday = weekday
        components.weekOfYear = currentWeek
        components.yearForWeekOfYear = currentYear
        return cal.date(from: components) ?? now
    }
}
