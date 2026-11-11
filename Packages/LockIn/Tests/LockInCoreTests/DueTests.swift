import Foundation
import Testing
@testable import LockInCore

struct DueTests {
    let cal = calendar()

    @Test func weeklyTaskIsDueOnlyOnItsWeekdays() {
        let t = task(schedule: .weekly([.monday, .wednesday]))
        #expect(t.isDue(on: day("2026-11-09"), calendar: cal))   // Monday
        #expect(!t.isDue(on: day("2026-11-10"), calendar: cal))  // Tuesday
        #expect(t.isDue(on: day("2026-11-11"), calendar: cal))   // Wednesday
    }

    @Test func onceTaskIsDueOnlyOnItsDay() {
        let t = task(schedule: .once(day("2026-11-10")))
        #expect(!t.isDue(on: day("2026-11-09"), calendar: cal))
        #expect(t.isDue(on: day("2026-11-10"), calendar: cal))
        #expect(!t.isDue(on: day("2026-11-11"), calendar: cal))
    }

    @Test func taskIsNotDueBeforeTheDayItWasCreated() {
        let t = task(createdOn: "2026-11-10")
        #expect(!t.isDue(on: day("2026-11-09"), calendar: cal))
        #expect(t.isDue(on: day("2026-11-10"), calendar: cal))
    }

    @Test func emptyWeeklyScheduleIsNeverDue() {
        #expect(!task(schedule: .weekly([])).isDue(on: day("2026-11-10"), calendar: cal))
    }

    @Test func roundTripsThroughJSON() throws {
        let t = task("Read", schedule: .once(day("2026-11-10")), requirement: .optional, startTime: time(18))
        let decoded = try JSONDecoder().decode(LockInTask.self, from: JSONEncoder().encode(t))
        #expect(decoded == t)
    }
}
