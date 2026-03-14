import Foundation

extension Date {

    /// ISO date string in the device's local timezone: "yyyy-MM-dd"
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: self)
    }

    /// Calendar weekday (1=Sun, 2=Mon … 7=Sat)
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }

    /// Full English weekday name, e.g. "Monday"
    var weekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: self)
    }

    /// Parses a "yyyy-MM-dd" string back to a Date at noon local time.
    static func from(dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.date(from: dateString)
    }

    /// ISO 8601 week string, e.g. "2026-W11". Resets on Monday.
    var isoWeekString: String {
        var cal = Calendar(identifier: .iso8601)
        cal.locale = Locale(identifier: "en_US_POSIX")
        let week = cal.component(.weekOfYear, from: self)
        let year = cal.component(.yearForWeekOfYear, from: self)
        return "\(year)-W\(String(format: "%02d", week))"
    }

    /// Returns [yesterday, 2 days ago, …, count days ago]
    func previousDays(count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (1...count).map {
            Calendar.current.date(byAdding: .day, value: -$0, to: self)!
        }
    }
}
