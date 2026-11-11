import Foundation
import Testing
@testable import LockInCore

struct TimeOfDayTests {
    @Test func acceptsQuarterHoursUpTo2330() {
        #expect(TimeOfDay(hour: 0, minute: 0) != nil)
        #expect(TimeOfDay(hour: 9, minute: 45) != nil)
        #expect(TimeOfDay(hour: 23, minute: 30) != nil)
    }

    @Test(arguments: [(23, 45), (9, 10), (24, 0), (-1, 0), (12, 60)])
    func rejectsInvalid(hour: Int, minute: Int) {
        #expect(TimeOfDay(hour: hour, minute: minute) == nil)
    }

    @Test func roundsAndCapsArbitraryClockTimes() {
        #expect(TimeOfDay.nearestAllowed(hour: 9, minute: 7) == time(9, 0))
        #expect(TimeOfDay.nearestAllowed(hour: 9, minute: 8) == time(9, 15))
        #expect(TimeOfDay.nearestAllowed(hour: 23, minute: 50) == time(23, 30))
    }

    @Test func comparesAndFormats() {
        #expect(time(8, 45) < time(9))
        #expect(time(18, 15).description == "18:15")
    }

    @Test func codesAsMinutes() throws {
        let data = try JSONEncoder().encode(time(18, 15))
        #expect(String(decoding: data, as: UTF8.self) == "1095")
        #expect(try JSONDecoder().decode(TimeOfDay.self, from: data) == time(18, 15))
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(TimeOfDay.self, from: Data("1100".utf8)) }
    }
}
