import Foundation
import Testing
@testable import LockInCore

/// Fixtures mirror v2's JSON exactly (default JSONEncoder, synthesized Codable, see v2 Task.swift on main).
struct V2ImportTests {
    let cal = calendar()
    let today = day("2026-11-10")

    let readID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let gymID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let onceDoneID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let onceOpenID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    let stepsID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!

    var tasksJSON: String {
        """
        [
          {"id":"\(readID)","title":"Read","recurrence":{"weekly":{"days":[1,2,3,4,5,6,7]}},"blocksApps":true,"createdAt":784000000},
          {"id":"\(gymID)","title":"Gym","recurrence":{"weekly":{"days":[2,4]}},"blocksApps":true,"createdAt":784000000,
           "blockingStartTime":{"hour":23,"minute":50},
           "location":{"latitude":47.37,"longitude":8.54,"name":"Gym","radius":200}},
          {"id":"\(onceDoneID)","title":"Taxes","recurrence":{"once":{"startDate":"2026-11-01"}},"blocksApps":true,"createdAt":784000000},
          {"id":"\(onceOpenID)","title":"Call bank","recurrence":{"once":{"startDate":"2026-11-08"}},"blocksApps":false,"createdAt":784000000,
           "blockingStartTime":{"hour":9,"minute":7}},
          {"id":"\(stepsID)","title":"Walk","recurrence":{"weekly":{"days":[2]}},"blocksApps":true,"createdAt":784000000,"stepTarget":8000}
        ]
        """
    }

    var completionJSON: String {
        #"{"2026-11-03":["\#(onceDoneID)"],"2026-11-10":["\#(readID)"],"2026-11-09":["\#(gymID)"]}"#
    }

    func snapshot(streak: String? = #"{"currentStreak":5,"longestStreak":9,"lastCompletedDate":"2026-11-09"}"#) -> V2Snapshot {
        V2Snapshot(
            tasks: Data(tasksJSON.utf8),
            completionLog: Data(completionJSON.utf8),
            streakData: streak.map { Data($0.utf8) },
            selectedWebDomains: ["https://Reddit.com/r/all", "reddit.com", "not a domain"],
            reminderNever: false,
            reminderHour: 21,
            reminderMinute: 10,
            hasCompletedOnboarding: true
        )
    }

    @Test func mapsTasks() throws {
        let result = try V2Import.map(snapshot(), today: today, calendar: cal)
        let byID = Dictionary(uniqueKeysWithValues: result.tasks.map { ($0.id, $0) })

        #expect(byID[readID]?.schedule == .weekly(Set(Weekday.allCases)))
        #expect(byID[readID]?.requirement == .required)
        #expect(byID[readID]?.startTime == nil)
        #expect(byID[gymID]?.schedule == .weekly([.monday, .wednesday]))
        #expect(byID[gymID]?.startTime == TimeOfDay(hour: 23, minute: 30))       // 23:50 is capped
        #expect(byID[onceDoneID] == nil)                                         // completed one-time Task is dropped
        #expect(byID[onceOpenID]?.schedule == .once(today))                      // still open: due today, like v2 showed it
        #expect(byID[onceOpenID]?.requirement == .optional)
        #expect(byID[onceOpenID]?.startTime == TimeOfDay(hour: 9, minute: 0))   // rounded to 15 minutes
        #expect(result.tasks.allSatisfy { $0.createdOn == today })
    }

    @Test func stepTargetsBecomeStepGoalsAndLocationsAreKeptForLater() throws {
        let result = try V2Import.map(snapshot(), today: today, calendar: cal)
        #expect(result.tasks.first { $0.id == stepsID }?.kind == .stepGoal(target: 8000))
        #expect(result.leftovers.locations[gymID] == V2Leftovers.Place(name: "Gym", latitude: 47.37, longitude: 8.54))
    }

    @Test func importsOnlyTodaysCompletions() throws {
        let result = try V2Import.map(snapshot(), today: today, calendar: cal)
        #expect(result.completions == CompletionLog([today: [readID]]))
    }

    @Test func settingsAndDomains() throws {
        let result = try V2Import.map(snapshot(), today: today, calendar: cal)
        #expect(result.settings.reminderTime == TimeOfDay(hour: 21, minute: 15))
        #expect(result.settings.hasCompletedOnboarding)
        #expect(result.settings.firstDay == today)
        #expect(result.customDomains == ["reddit.com"])
    }

    @Test func reminderNeverMeansOff() throws {
        var s = snapshot()
        s.reminderNever = true
        #expect(try V2Import.map(s, today: today, calendar: cal).settings.reminderTime == nil)
    }

    @Test func missingReminderUsesTheDefault() throws {
        var s = snapshot()
        s.reminderHour = nil
        s.reminderMinute = nil
        #expect(try V2Import.map(s, today: today, calendar: cal).settings.reminderTime == Settings.defaultReminderTime)
    }

    @Test(arguments: [
        ("2026-11-09", 5, StreakSeed(count: 5, asOf: DayKey("2026-11-09")!) as StreakSeed?),  // kept through yesterday
        ("2026-11-10", 5, StreakSeed(count: 4, asOf: DayKey("2026-11-09")!)),                // today already counted
        ("2026-11-07", 5, nil),                                                              // v2 Streak already broken
    ])
    func streakSeed(lastCompleted: String, current: Int, expected: StreakSeed?) throws {
        let json = #"{"currentStreak":\#(current),"longestStreak":9,"lastCompletedDate":"\#(lastCompleted)"}"#
        #expect(try V2Import.map(snapshot(streak: json), today: today, calendar: cal).settings.streakSeed == expected)
    }

    @Test func importedStreakContinuesWhenTodayIsKept() throws {
        let result = try V2Import.map(snapshot(), today: today, calendar: cal)
        var log = result.completions
        for t in result.tasks where t.isRequired { log.set(t.id, completed: true, on: today) }
        let todayView = Today(day: today, tasks: result.tasks, completions: log, calendar: cal)
        #expect(Streak.current(records: [:], today: todayView, firstDay: today, seed: result.settings.streakSeed, calendar: cal) == 6)
    }

    @Test func corruptTasksThrow() {
        var s = snapshot()
        s.tasks = Data("garbage".utf8)
        #expect(throws: (any Error).self) { try V2Import.map(s, today: today, calendar: cal) }
    }

    @Test func missingOptionalDocumentsAreFine() throws {
        let s = V2Snapshot(tasks: nil, completionLog: nil, streakData: nil, selectedWebDomains: nil,
                           reminderNever: false, reminderHour: nil, reminderMinute: nil, hasCompletedOnboarding: true)
        let result = try V2Import.map(s, today: today, calendar: cal)
        #expect(result.tasks.isEmpty)
        #expect(result.settings.streakSeed == nil)
    }

    @Test func isPresentDetectsV2Data() {
        #expect(snapshot().isPresent)
        #expect(!V2Snapshot(tasks: nil, completionLog: nil, streakData: nil, selectedWebDomains: nil,
                            reminderNever: false, reminderHour: nil, reminderMinute: nil, hasCompletedOnboarding: false).isPresent)
    }
}
