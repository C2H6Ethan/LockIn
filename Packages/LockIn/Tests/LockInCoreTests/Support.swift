import Foundation
@testable import LockInCore

/// Gregorian calendar pinned to a time zone so tests never depend on the machine.
func calendar(_ tz: String = "Europe/Zurich") -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: tz)!
    return c
}

func day(_ s: String) -> DayKey { DayKey(s)! }

func time(_ hour: Int, _ minute: Int = 0) -> TimeOfDay { TimeOfDay(hour: hour, minute: minute)! }

/// A wall-clock instant on a given Day in the calendar's time zone.
func instant(_ dayString: String, _ hour: Int, _ minute: Int = 0, in cal: Calendar = calendar()) -> Date {
    let d = day(dayString)
    return cal.date(from: DateComponents(year: d.year, month: d.month, day: d.day, hour: hour, minute: minute))!
}

func task(
    _ title: String = "Task",
    schedule: Schedule = .weekly(Set(Weekday.allCases)),
    requirement: Requirement = .required,
    startTime: TimeOfDay? = nil,
    createdOn: String = "2026-01-01"
) -> LockInTask {
    LockInTask(title: title, schedule: schedule, requirement: requirement, startTime: startTime, createdOn: day(createdOn))
}
