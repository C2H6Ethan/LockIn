import XCTest
@testable import LockIn

/// Tests covering every interaction between task editing (updateTask) and streak state.
/// Focuses on once tasks rescheduled via "Today / Tomorrow / Pick date", weekly day changes,
/// and recurrence type conversions (once ↔ weekly).
final class TaskEditStreakTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.edit.\(UUID().uuidString)")
        store.streakFreezeCount = 0
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    private func addOnce(startDate: Date, createdAt: Date? = nil) -> Task {
        let task = Task(
            title: "Once",
            recurrence: .once(startDate: startDate.dateString),
            blocksApps: true,
            createdAt: createdAt ?? startDate
        )
        store.addTask(task)
        return task
    }

    private func addWeekly(days: Set<Int>, createdAt: Date) -> Task {
        let task = Task(title: "Weekly", recurrence: .weekly(days: days), blocksApps: true, createdAt: createdAt)
        store.addTask(task)
        return task
    }

    /// Reschedule a once task to a new startDate (simulates pressing Today / Tomorrow / Pick date).
    private func reschedule(_ task: Task, to newStart: Date) -> Task {
        let updated = Task(id: task.id, title: task.title,
                          recurrence: .once(startDate: newStart.dateString),
                          blocksApps: task.blocksApps, createdAt: task.createdAt)
        store.updateTask(updated)
        return updated
    }

    /// Change a once task to a weekly task.
    private func makeWeekly(_ task: Task, days: Set<Int>) -> Task {
        let updated = Task(id: task.id, title: task.title,
                          recurrence: .weekly(days: days),
                          blocksApps: task.blocksApps, createdAt: task.createdAt)
        store.updateTask(updated)
        return updated
    }

    /// Change a weekly task to a once task.
    private func makeOnce(_ task: Task, startDate: Date) -> Task {
        let updated = Task(id: task.id, title: task.title,
                          recurrence: .once(startDate: startDate.dateString),
                          blocksApps: task.blocksApps, createdAt: task.createdAt)
        store.updateTask(updated)
        return updated
    }

    /// Change which days a weekly task runs on.
    private func changeDays(_ task: Task, to days: Set<Int>) -> Task {
        let updated = Task(id: task.id, title: task.title,
                          recurrence: .weekly(days: days),
                          blocksApps: task.blocksApps, createdAt: task.createdAt)
        store.updateTask(updated)
        return updated
    }

    // MARK: - Once task rescheduled to Tomorrow — disappears from today

    func testRescheduleOnce_toTomorrow_disappearsFromBuildTodayTasks() {
        let today    = date(2026, 3, 10)
        let tomorrow = date(2026, 3, 11)
        let task = addOnce(startDate: today)

        // Before reschedule: appears in today's tasks
        let before = store.buildTodayTasks(on: today)
        XCTAssertTrue(before.contains { $0.id == task.id }, "Task should be in today's tasks before reschedule")

        // Press "Tomorrow"
        reschedule(task, to: tomorrow)

        // After reschedule: gone from today
        let after = store.buildTodayTasks(on: today)
        XCTAssertFalse(after.contains { $0.id == task.id }, "Task should not appear today after rescheduling to tomorrow")
    }

    // MARK: - Once task rescheduled to Tomorrow — appears tomorrow

    func testRescheduleOnce_toTomorrow_appearsTomorrow() {
        let today    = date(2026, 3, 10)
        let tomorrow = date(2026, 3, 11)
        let task = addOnce(startDate: today)
        reschedule(task, to: tomorrow)

        let tomorrowTasks = store.buildTodayTasks(on: tomorrow)
        XCTAssertTrue(tomorrowTasks.contains { $0.id == task.id }, "Rescheduled task should appear tomorrow")
    }

    // MARK: - Reschedule to Tomorrow does NOT break streak (today already counted)

    func testRescheduleOnce_toTomorrow_afterTodayStreakCounted_streakUnaffected() {
        // Build a 3-day streak. Today: complete the weekly task → streak=4 counted.
        // Then reschedule once task to tomorrow. Streak should stay at 4.
        let mon  = date(2026, 3, 9)
        let tue  = date(2026, 3, 10)
        let wed  = date(2026, 3, 11)
        let thu  = date(2026, 3, 12) // today
        let fri  = date(2026, 3, 13)

        let daily = addWeekly(days: [2,3,4,5,6], createdAt: mon)
        let once  = addOnce(startDate: thu)

        // Build streak Mon–Wed
        store.completeTask(daily.id, on: mon.dateString); store.updateStreak(for: mon.dateString)
        store.completeTask(daily.id, on: tue.dateString); store.updateStreak(for: tue.dateString)
        store.completeTask(daily.id, on: wed.dateString); store.updateStreak(for: wed.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 3)

        // Thursday: complete BOTH daily and once → streak=4
        store.completeTask(daily.id, on: thu.dateString)
        store.completeTask(once.id,  on: thu.dateString)
        store.updateStreak(for: thu.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 4)

        // Now user presses "Tomorrow" on the once task (streak already counted)
        reschedule(once, to: fri)

        // Streak must be unaffected — updateTask does not touch streak
        XCTAssertEqual(store.streakData.currentStreak, 4)
        XCTAssertEqual(store.streakData.lastCompletedDate, thu.dateString)
    }

    // MARK: - Reschedule to Tomorrow then complete tomorrow → streak continues

    func testRescheduleOnce_toTomorrow_completeNextDay_streakContinues() {
        let mon = date(2026, 3, 9)
        let tue = date(2026, 3, 10) // today
        let wed = date(2026, 3, 11) // tomorrow

        let daily = addWeekly(days: [2,3,4], createdAt: mon)
        let once  = addOnce(startDate: tue)

        // Monday: complete daily → streak=1
        store.completeTask(daily.id, on: mon.dateString); store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Tuesday: press "Tomorrow" on once task — skip it
        // Complete only the daily task (once task was rescheduled away)
        reschedule(once, to: wed)
        store.completeTask(daily.id, on: tue.dateString)
        store.updateStreak(for: tue.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 2) // once task not in today's required tasks

        // Wednesday: complete daily + once task (which now starts Wed)
        store.completeTask(daily.id, on: wed.dateString)
        store.completeTask(once.id,  on: wed.dateString)
        store.updateStreak(for: wed.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 3)
    }

    // MARK: - Keeping pressing Tomorrow every day — streak never broken

    func testRescheduleOnce_tomorrowEveryDay_streakUnbroken() {
        // Scenario: user creates a once task and presses Tomorrow every single day for 5 days.
        // They complete their daily task each day. Streak should reach 5.
        let base = date(2026, 3, 9) // Mon
        var days: [Date] = (0..<5).map { i in
            var c = DateComponents(); c.year = 2026; c.month = 3; c.day = 9 + i; c.hour = 12
            return Calendar.current.date(from: c)!
        }

        let daily = addWeekly(days: [2,3,4,5,6], createdAt: base)
        var onceTask = addOnce(startDate: days[0]) // starts Mon

        for (i, day) in days.enumerated() {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day)!

            // Reschedule to tomorrow (user presses "Tomorrow")
            onceTask = reschedule(onceTask, to: tomorrow)

            // Complete the daily task for today
            store.completeTask(daily.id, on: day.dateString)
            store.updateStreak(for: day.dateString)

            XCTAssertEqual(store.streakData.currentStreak, i + 1, "Day \(i+1)")
        }

        // Once task was never completed and never blocked the streak
        XCTAssertEqual(store.streakData.currentStreak, 5)
        _ = days // suppress unused warning
    }

    // MARK: - checkAndUpdateStreak: once task rescheduled to future — NOT a miss

    func testCheckAndUpdate_onceTaskRescheduledToFuture_notCountedAsMiss() {
        // User had once task starting yesterday. Before app opens today, they rescheduled it to tomorrow.
        // checkAndUpdateStreak should NOT count yesterday as missed (startDate is now tomorrow).
        let yesterday = date(2026, 3, 9)
        let today     = date(2026, 3, 10)
        let tomorrow  = date(2026, 3, 11)

        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: yesterday.dateString)
        store.streakFreezeWeekString = today.isoWeekString

        // Task originally for yesterday, rescheduled to tomorrow
        let task = addOnce(startDate: yesterday, createdAt: yesterday)
        _ = reschedule(task, to: tomorrow) // startDate now = tomorrow

        store.checkAndUpdateStreak(today: today)

        // No missed day (task now starts tomorrow, not yesterday)
        XCTAssertEqual(store.streakData.currentStreak, 3, "Rescheduled-away once task must not count as a miss")
        XCTAssertFalse(store.pendingFreezeOffer)
    }

    // MARK: - Once task rescheduled to a PAST date — treated as missed

    func testCheckAndUpdate_onceTaskRescheduledToPastDate_countedAsMiss() {
        // User has a once task rescheduled to 2 days ago and never completed it.
        // checkAndUpdateStreak must count it as a missed day.
        let threeDaysAgo = date(2026, 3, 8)
        let twoDaysAgo   = date(2026, 3, 9)
        let today        = date(2026, 3, 11)

        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: threeDaysAgo.dateString)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString

        // Task created yesterday, but rescheduled to startDate = 2 days ago
        let task = addOnce(startDate: twoDaysAgo, createdAt: twoDaysAgo)
        _ = task // never completed → genuine miss for that date

        store.checkAndUpdateStreak(today: today)
        XCTAssertEqual(store.streakData.currentStreak, 0, "Once task in the past that was never completed should reset streak")
    }

    // MARK: - updateStreak gap check: once task rescheduled to future — not a gap blocker

    func testUpdateStreak_gapDay_onceTaskRescheduledToFuture_gapTreatedAsFree() {
        // lastCompletedDate = Mon. The only task on Tue was a once task, but user rescheduled it to Thu.
        // When completing Wed tasks, gap check for Tue should find no tasks → free → streak continues.
        let mon = date(2026, 3, 9)
        let tue = date(2026, 3, 10)
        let wed = date(2026, 3, 11)
        let thu = date(2026, 3, 12)

        let monTask = addWeekly(days: [2], createdAt: mon) // Mon only
        let wedTask = addWeekly(days: [4], createdAt: mon) // Wed only
        let onceTask = addOnce(startDate: tue, createdAt: mon)

        store.completeTask(monTask.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Reschedule once task away from Tuesday to Thursday
        _ = reschedule(onceTask, to: thu)

        // Wednesday: complete wedTask
        store.completeTask(wedTask.id, on: wed.dateString)
        store.updateStreak(for: wed.dateString)

        // Gap (Tue) now has no tasks (once task rescheduled away) → free pass → streak=2
        XCTAssertEqual(store.streakData.currentStreak, 2,
            "Rescheduling once task away from gap day should make it task-free (streak continues)")
    }

    // MARK: - Once task completed today, then rescheduled to future — completion preserved

    func testCompletedOnceTask_rescheduledToFuture_completionLogPreserved() {
        // Complete a once task today, then reschedule it to tomorrow (unusual but possible).
        // The completionLog entry for today should survive the reschedule.
        let today    = date(2026, 3, 10)
        let tomorrow = date(2026, 3, 11)

        let task = addOnce(startDate: today)
        store.completeTask(task.id, on: today.dateString)

        // Verify completion exists
        XCTAssertTrue(store.completionLog[today.dateString]?.contains(task.id) ?? false)

        // Reschedule to tomorrow
        _ = reschedule(task, to: tomorrow)

        // Completion log for today still contains the entry (updateTask doesn't clear it)
        XCTAssertTrue(store.completionLog[today.dateString]?.contains(task.id) ?? false,
            "Rescheduling must not erase a completed entry from completionLog")
    }

    // MARK: - Weekly task: add today's weekday after all tasks done → task appears tomorrow as carryover

    func testWeeklyEdit_addTodayWeekday_afterStreakCounted_appearsAsTomorrowCarryover() {
        let mon = date(2026, 3, 9)  // weekday 2
        let tue = date(2026, 3, 10) // weekday 3

        let taskA = addWeekly(days: [2,3], createdAt: mon) // Mon+Tue
        var taskB = addWeekly(days: [3],   createdAt: mon) // Tue only

        // Monday: complete taskA (taskB not on Mon) → streak=1, lastCompletedDate=Mon
        store.completeTask(taskA.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Edit taskB to also run on Monday (after streak was counted for Mon)
        taskB = changeDays(taskB, to: [2, 3])

        // Monday now has an incomplete task (taskB) — streak rolls back
        XCTAssertEqual(store.streakData.currentStreak, 0)
        XCTAssertNil(store.streakData.lastCompletedDate)

        // Tuesday: taskB appears for today (Tue) AND as a carryover from Monday (since it was
        // never completed on Mon even though it is now active for Mon).
        let tueTasks = store.buildTodayTasks(on: tue)
        // taskA and taskB should both appear (scheduled today)
        // taskB's Mon instance appears as a carryover too, but seenIds deduplicates it
        let ids = Set(tueTasks.map { $0.id })
        XCTAssertTrue(ids.contains(taskA.id), "taskA should be in Tue's tasks")
        XCTAssertTrue(ids.contains(taskB.id), "taskB should be in Tue's tasks")
    }

    // MARK: - Weekly task: remove today's weekday after completing → streak still counted

    func testWeeklyEdit_removeTodayWeekday_afterCompleted_streakUnaffected() {
        let mon = date(2026, 3, 9)  // weekday 2
        let tue = date(2026, 3, 10)

        let task = addWeekly(days: [2, 3], createdAt: mon)

        store.completeTask(task.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Remove Monday from the task's active days
        _ = changeDays(task, to: [3]) // now Tue only

        // Streak and lastCompletedDate unchanged
        XCTAssertEqual(store.streakData.currentStreak, 1)
        XCTAssertEqual(store.streakData.lastCompletedDate, mon.dateString)

        // Tuesday: only task = taskA for Tue. Mon no longer counts as active for taskA.
        // Gap Mon → Tue: Mon had task (createdAt=Mon, activeDays=[3] doesn't include Mon now,
        // but we check at time of updateStreak). Actually: after edit, activeDays=[3] (Tue only).
        // Mon (weekday 2) not in [3] → gap day Mon has no tasks → free → streak=2.
        store.completeTask(task.id, on: tue.dateString)
        store.updateStreak(for: tue.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 2)
    }

    // MARK: - Weekly → Once conversion: task removed from future weekly schedule

    func testWeeklyToOnce_conversion_taskNoLongerInWeeklySchedule() {
        let mon = date(2026, 3, 9)
        let tue = date(2026, 3, 10)
        let wed = date(2026, 3, 11)

        var task = addWeekly(days: [2,3,4], createdAt: mon) // Mon–Wed

        // Complete Monday
        store.completeTask(task.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Convert to once task starting Wednesday
        task = makeOnce(task, startDate: wed)

        // Tuesday: buildTodayTasks should NOT include this task (it's now a once task starting Wed)
        let tueTasks = store.buildTodayTasks(on: tue)
        XCTAssertFalse(tueTasks.contains { $0.id == task.id },
            "Converted-to-once task should not appear on Tuesday (startDate=Wed)")

        // Gap check for Wed: Tue has NO task (converted away) → free → streak=2
        store.updateStreak(for: tue.dateString) // no tasks today → guard fires (tasks not empty, remaining empty)
        // Actually remaining IS empty since task not on Tue → updateStreak fires
        XCTAssertEqual(store.streakData.currentStreak, 2, "Tue is task-free after conversion → streak continues")
    }

    // MARK: - Once → Weekly conversion: task now appears on scheduled weekdays

    func testOnceToWeekly_conversion_taskAppearsOnScheduledDays() {
        let mon = date(2026, 3, 9)
        let wed = date(2026, 3, 11) // weekday 4

        var task = addOnce(startDate: mon, createdAt: mon)

        // Convert to weekly on Wed–Fri
        task = makeWeekly(task, days: [4,5,6])

        // Wednesday: task should appear
        let wedTasks = store.buildTodayTasks(on: wed)
        XCTAssertTrue(wedTasks.contains { $0.id == task.id },
            "After converting to weekly, task should appear on Wednesday")
    }

    // MARK: - Once → Weekly conversion mid-streak: gap check uses new recurrence

    func testOnceToWeekly_midStreak_gapCheckUsesNewRecurrence() {
        // Build streak Mon. Tue: once task exists (startDate=Tue). Before Tue's tasks are done,
        // convert it to a weekly task on Thu only (not Tue). Tue becomes task-free for this task.
        // Complete another Tue task → streak should continue (Tue has the other task done).
        let mon = date(2026, 3, 9)  // weekday 2
        let tue = date(2026, 3, 10) // weekday 3
        let thu = date(2026, 3, 12) // weekday 5

        let monTask = addWeekly(days: [2], createdAt: mon) // Mon only
        var onceTask = addOnce(startDate: tue, createdAt: mon)

        store.completeTask(monTask.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Convert once task (Tue) to weekly on Thu — Tue now has no tasks
        onceTask = makeWeekly(onceTask, days: [5]) // Thu only

        // Tuesday: only monTask is NOT on Tue. onceTask converted to Thu. No Tue tasks.
        // buildTodayTasks(Tue) should be empty → updateStreak fires.
        let tueTasks = store.buildTodayTasks(on: tue)
        XCTAssertFalse(tueTasks.contains { $0.id == onceTask.id },
            "Converted-to-Thu-weekly task should not appear on Tuesday")

        store.updateStreak(for: tue.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 2, "Tue became task-free after conversion")
        _ = thu // suppress
    }

    // MARK: - checkAndUpdateStreak: rescheduled once task then missed other task

    func testCheckAndUpdate_rescheduledOncePlusMissedWeekly_missedWeeklyCountsOnly() {
        // Yesterday: weekly task (missed) + once task (rescheduled to today before app open).
        // checkAndUpdateStreak should detect 1 missed day (the weekly), not 2.
        let twoDaysAgo = date(2026, 3, 8) // last completed
        let yesterday  = date(2026, 3, 9)
        let today      = date(2026, 3, 10) // weekday 3

        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: twoDaysAgo.dateString)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString

        // Weekly task scheduled for yesterday — never completed → missed
        _ = addWeekly(days: [2], createdAt: twoDaysAgo) // Mon (weekday 2) = yesterday

        // Once task that STARTED yesterday but was rescheduled to today BEFORE app open
        let once = addOnce(startDate: yesterday, createdAt: twoDaysAgo)
        _ = reschedule(once, to: today) // now starts today

        store.checkAndUpdateStreak(today: today)

        // 1 missed day (weekly), freeze drained → streak resets
        XCTAssertEqual(store.streakData.currentStreak, 0,
            "Only the weekly task counts as missed — rescheduled once task is not a miss")
    }

    // MARK: - Repeated Tomorrow presses: each reschedule keeps streak clean

    func testRepeatedTomorrowPresses_weeklyTasksComplete_streakBuildsCorrectly() {
        // Scenario reproducing the reported bug:
        // User has a daily task. Creates a once task and presses Tomorrow repeatedly
        // over 5 days while completing the daily each day.
        // Streak should reach 5 with no corruption.
        let mon = date(2026, 3, 9)
        let tue = date(2026, 3, 10)
        let wed = date(2026, 3, 11)
        let thu = date(2026, 3, 12)
        let fri = date(2026, 3, 13)
        let sat = date(2026, 3, 14)

        let daily = addWeekly(days: [2,3,4,5,6], createdAt: mon)
        var once = addOnce(startDate: mon, createdAt: mon) // starts Mon

        // Drain freeze all week
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = mon.isoWeekString

        let days = [mon, tue, wed, thu, fri]

        for (i, day) in days.enumerated() {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: day)!

            // checkAndUpdateStreak (app open)
            store.checkAndUpdateStreak(today: day)
            XCTAssertFalse(store.pendingFreezeOffer, "No freeze offer expected (once task rescheduled forward)")

            // Press "Tomorrow" on the once task
            once = reschedule(once, to: tomorrow)

            // Complete the daily task
            store.completeTask(daily.id, on: day.dateString)
            store.updateStreak(for: day.dateString)

            XCTAssertEqual(store.streakData.currentStreak, i + 1, "\(day.dateString): streak should be \(i+1)")
        }

        // Verify final state
        XCTAssertEqual(store.streakData.currentStreak, 5)
        XCTAssertEqual(store.streakData.lastCompletedDate, fri.dateString)

        // Saturday: once task now starts Sat (was pushed to Sat by the last Tomorrow press on Fri)
        let satTasks = store.buildTodayTasks(on: sat)
        XCTAssertTrue(satTasks.contains { $0.id == once.id },
            "Once task should finally appear on Saturday after 5 days of Tomorrow presses")
    }

    // MARK: - Edit changes title only — streak and tasks unaffected

    func testEditTitleOnly_streakAndTasksUnaffected() {
        let mon = date(2026, 3, 9)
        var task = addWeekly(days: [2,3,4], createdAt: mon)

        store.completeTask(task.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Edit title only
        let updated = Task(id: task.id, title: "Renamed", recurrence: task.recurrence,
                          blocksApps: task.blocksApps, createdAt: task.createdAt)
        store.updateTask(updated)
        task = updated

        XCTAssertEqual(store.streakData.currentStreak, 1, "Title-only edit must not change streak")
        XCTAssertTrue(store.completionLog[mon.dateString]?.contains(task.id) ?? false,
            "Completion log must survive title edit")
    }

    // MARK: - Edit adds tomorrow to a once task (startDate was today, now tomorrow)
    //        while today already had other tasks → streak must not regress

    func testRescheduleOnce_fromTodayToTomorrow_otherTasksCompleted_noStreakRegression() {
        let mon = date(2026, 3, 9)
        let tue = date(2026, 3, 10)

        let daily = addWeekly(days: [2,3], createdAt: mon)
        let once  = addOnce(startDate: mon, createdAt: mon)

        // Monday: complete BOTH daily and once → streak=1
        store.completeTask(daily.id, on: mon.dateString)
        store.completeTask(once.id,  on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Reschedule once task to Tuesday (after it was already completed — odd but possible)
        _ = reschedule(once, to: tue)

        // Streak must still be 1
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Tuesday: daily + once (rescheduled here). Both complete → streak=2.
        store.completeTask(daily.id, on: tue.dateString)
        store.completeTask(once.id,  on: tue.dateString)
        store.updateStreak(for: tue.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 2)
    }

    // MARK: - Once task startDate moved to before lastCompletedDate — doesn't create phantom miss

    func testRescheduleOnce_toPastDate_beforeLastCompleted_gapCheckIgnoresIt() {
        // lastCompletedDate = Mon. Reschedule a once task to have startDate = Mon (same day).
        // Mon now has an incomplete task → streak rolls back to 0.
        // Completing the carryover on Tue starts a fresh streak = 1.
        let mon = date(2026, 3, 9)  // lastCompletedDate
        let tue = date(2026, 3, 10)

        let monTask = addWeekly(days: [2], createdAt: mon) // Mon only
        let once = addOnce(startDate: tue, createdAt: mon) // originally Tue

        // Complete Monday
        store.completeTask(monTask.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString) // streak=1, lastCompletedDate=Mon

        // Reschedule once to Monday — Mon now has incomplete once task → streak rolls back
        _ = reschedule(once, to: mon)
        XCTAssertEqual(store.streakData.currentStreak, 0,
            "Moving incomplete task to lastCompletedDate should roll back streak")

        // Tuesday: Once task appears as carryover from Mon
        let beforeCompletion = store.buildTodayTasks(on: tue)
        for task in beforeCompletion {
            store.completeTask(task.id, on: task.scheduledDateString)
        }
        store.updateStreak(for: tue.dateString)

        // Fresh streak from Tue (Mon's once task was completed as carryover, not on Mon itself)
        XCTAssertEqual(store.streakData.currentStreak, 1,
            "Completing carryover on Tue starts fresh streak since Mon once task wasn't logged on Mon")
    }

    // MARK: - Changing blocksApps flag doesn't affect streak

    func testEditBlocksApps_noStreakEffect() {
        let mon = date(2026, 3, 9)
        let task = addWeekly(days: [2,3,4], createdAt: mon)
        store.completeTask(task.id, on: mon.dateString)
        store.updateStreak(for: mon.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Toggle blocksApps
        let updated = Task(id: task.id, title: task.title, recurrence: task.recurrence,
                          blocksApps: false, createdAt: task.createdAt)
        store.updateTask(updated)

        XCTAssertEqual(store.streakData.currentStreak, 1)
        XCTAssertEqual(store.streakData.lastCompletedDate, mon.dateString)
    }

    // MARK: - Delete task restores streak

    /// Deleting a task added for today should restore the streak if all remaining tasks are done.
    /// Scenario: complete all tasks today (streak advances), add a new task for today
    /// (streak decrements — mirrors TodayViewModel.addTask logic), delete it → streak restores.
    func testDeleteTask_restoresStreakWhenTodayBecomesComplete() {
        // Wednesday March 25 2026, weekday 4
        let today = date(2026, 3, 25)
        let todayWeekday = Calendar.current.component(.weekday, from: today)
        let todayString = today.dateString
        let yesterday = date(2026, 3, 24)

        // Existing task completed today → streak = 1
        let existing = Task(title: "gym", activeDays: [todayWeekday], blocksApps: true, createdAt: today)
        store.addTask(existing)
        store.completeTask(existing.id, on: todayString)
        store.updateStreak(for: todayString)
        XCTAssertEqual(store.streakData.currentStreak, 1)
        XCTAssertEqual(store.streakData.lastCompletedDate, todayString)

        // Add a new task for today — TodayViewModel decrements the streak
        let newTask = Task(title: "new", activeDays: [todayWeekday], blocksApps: true, createdAt: today)
        store.addTask(newTask)
        var data = store.streakData
        data.currentStreak = max(0, data.currentStreak - 1) // = 0
        data.lastCompletedDate = data.currentStreak == 0 ? nil : yesterday.dateString
        store.streakData = data
        XCTAssertEqual(store.streakData.currentStreak, 0)

        // Delete the new task → all remaining tasks are complete → streak should restore to 1
        store.removeTask(id: newTask.id, today: today)
        XCTAssertEqual(store.streakData.currentStreak, 1)
        XCTAssertEqual(store.streakData.lastCompletedDate, todayString)
    }

    /// Same as above but streak > 1 to confirm delta is exactly +1, not reset to 1.
    func testDeleteTask_restoresHigherStreak() {
        let today = date(2026, 3, 25)
        let todayWeekday = Calendar.current.component(.weekday, from: today)
        let todayString = today.dateString
        let yesterday = date(2026, 3, 24)

        let existing = Task(title: "gym", activeDays: [todayWeekday], blocksApps: true, createdAt: today)
        store.addTask(existing)
        store.completeTask(existing.id, on: todayString)
        // Pretend streak was already 5 going into today
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5, lastCompletedDate: yesterday.dateString)
        store.updateStreak(for: todayString)
        XCTAssertEqual(store.streakData.currentStreak, 6)

        // Add task → decrement to 5
        let newTask = Task(title: "new", activeDays: [todayWeekday], blocksApps: true, createdAt: today)
        store.addTask(newTask)
        var data = store.streakData
        data.currentStreak = 5
        data.lastCompletedDate = yesterday.dateString
        store.streakData = data

        // Delete → should restore to 6
        store.removeTask(id: newTask.id, today: today)
        XCTAssertEqual(store.streakData.currentStreak, 6)
        XCTAssertEqual(store.streakData.lastCompletedDate, todayString)
    }
}
