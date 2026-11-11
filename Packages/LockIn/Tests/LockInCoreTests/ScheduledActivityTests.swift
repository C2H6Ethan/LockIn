import Foundation
import Testing
@testable import LockInCore

struct ScheduledActivityTests {
    let today = day("2026-11-10")

    @Test func alwaysIncludesTheDayActivity() {
        #expect(ScheduledActivity.desired(tasks: [], today: today) == [.day])
    }

    @Test func addsOneActivityPerDistinctRequiredStartTime() {
        let tasks = [
            task("A", startTime: time(9)),
            task("B", startTime: time(9)),
            task("C", startTime: time(18)),
            task("D"),
            task("E", requirement: .optional, startTime: time(12)),
        ]
        #expect(ScheduledActivity.desired(tasks: tasks, today: today) == [.day, .start(time(9)), .start(time(18))])
    }

    @Test func ignoresOnceTasksInThePast() {
        let past = task(schedule: .once(day("2026-11-09")), startTime: time(9))
        let future = task(schedule: .once(day("2026-11-11")), startTime: time(10))
        #expect(ScheduledActivity.desired(tasks: [past, future], today: today) == [.day, .start(time(10))])
    }

    @Test(arguments: [ScheduledActivity.day, .start(time(0)), .start(time(9, 45)), .start(time(23, 30))])
    func nameRoundTrips(activity: ScheduledActivity) {
        #expect(ScheduledActivity(name: activity.name) == activity)
    }

    @Test func namesAreStable() {
        #expect(ScheduledActivity.day.name == "day")
        #expect(ScheduledActivity.start(time(9, 45)).name == "start-0945")
        #expect(ScheduledActivity(name: "start-0950") == nil)
        #expect(ScheduledActivity(name: "bogus") == nil)
    }

    @Test func intervalsRunFromStartToEndOfDay() {
        #expect(ScheduledActivity.day.intervalStart == time(0))
        #expect(ScheduledActivity.start(time(18)).intervalStart == time(18))
    }
}

struct ReminderActivityTests {
    let today = day("2026-11-10")

    @Test func reminderActivityIsDesiredOnlyWhenTheReminderIsOn() {
        #expect(ScheduledActivity.desired(tasks: [], reminderTime: time(20), today: today) == [.day, .reminder(time(20))])
        #expect(ScheduledActivity.desired(tasks: [], reminderTime: nil, today: today) == [.day])
    }

    @Test func reminderAndStartTimeAtTheSameMinuteAreSeparateActivities() {
        let desired = ScheduledActivity.desired(tasks: [task(startTime: time(20))], reminderTime: time(20), today: today)
        #expect(desired == [.day, .start(time(20)), .reminder(time(20))])
    }

    @Test func reminderNameRoundTrips() {
        #expect(ScheduledActivity.reminder(time(20, 15)).name == "reminder-2015")
        #expect(ScheduledActivity(name: "reminder-2015") == .reminder(time(20, 15)))
        #expect(ScheduledActivity.reminder(time(20, 15)).intervalStart == time(20, 15))
    }
}

struct ReminderContentTests {
    let cal = calendar()
    let d = day("2026-11-10")

    @Test func nothingOwedMeansNoReminder() {
        let read = task("Read")
        var log = CompletionLog()
        log.set(read.id, completed: true, on: d)
        #expect(Reminder.content(tasks: [read], completions: log, day: d, calendar: cal) == nil)
        #expect(Reminder.content(tasks: [task("Stretch", requirement: .optional)], completions: CompletionLog(), day: d, calendar: cal) == nil)
        #expect(Reminder.content(tasks: [], completions: CompletionLog(), day: d, calendar: cal) == nil)
    }

    @Test func oneTaskLeftIsNamed() {
        let content = Reminder.content(tasks: [task("Read 20 pages")], completions: CompletionLog(), day: d, calendar: cal)
        #expect(content == Reminder.Content(title: "Read 20 pages is still open", body: "Finish it to keep your streak."))
    }

    @Test func severalTasksLeftAreCounted() {
        let content = Reminder.content(tasks: [task("A"), task("B"), task("C", requirement: .optional)], completions: CompletionLog(), day: d, calendar: cal)
        #expect(content == Reminder.Content(title: "2 tasks left today", body: "Finish them to keep your streak."))
    }
}
