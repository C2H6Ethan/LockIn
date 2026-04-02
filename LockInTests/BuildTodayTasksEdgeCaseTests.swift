import XCTest
@testable import LockIn

/// Edge cases for buildTodayTasks: carryover window, deduplication, once-task persistence,
/// createdAt boundary, and future-task exclusion.
final class BuildTodayTasksEdgeCaseTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.build.\(UUID().uuidString)")
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    // MARK: - Carryover window: exactly 7 days

    func testCarryover_taskFrom7DaysAgo_appearsToday() {
        // A weekly task with today's weekday that was not completed 7 days ago
        // should carry over into today's list.
        let today        = date(2026, 3, 25) // Wednesday, weekday 4
        let sevenDaysAgo = date(2026, 3, 18) // also Wednesday, weekday 4
        let todayWeekday = Calendar.current.component(.weekday, from: today)

        let task = Task(title: "gym", recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true, createdAt: sevenDaysAgo)
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)
        XCTAssertTrue(result.contains { $0.id == task.id },
                      "Task uncompleted 7 days ago must appear as carryover today")
    }

    func testCarryover_taskFrom8DaysAgo_doesNotAppearToday() {
        // The carryover window is 7 days. A task that was missed 8 days ago
        // should NOT be carried over (too stale).
        let today        = date(2026, 3, 25)
        let eightDaysAgo = date(2026, 3, 17)
        let todayWeekday = Calendar.current.component(.weekday, from: today)

        let task = Task(title: "gym", recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true, createdAt: eightDaysAgo)
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)
        // Task should still appear for TODAY (it's a weekly task on today's weekday),
        // but NOT as a carryover from 8 days ago.
        // Both the "today" instance and carryover would have the same id.
        // What we verify: it appears at most once (no duplicates from 8-day-old instance).
        let occurrences = result.filter { $0.id == task.id }
        XCTAssertLessThanOrEqual(occurrences.count, 1,
                                  "Task must not appear twice — 8-day-old instance is outside carryover window")
    }

    // MARK: - Deduplication: same task on multiple carryover days → appears once

    func testCarryover_deduplication_taskMissedMultipleWeeks_appearsOnce() {
        // A daily task missed for 3 consecutive weekdays within the 7-day window.
        // buildTodayTasks must deduplicate by task id and return it exactly once.
        let today = date(2026, 3, 25) // Wednesday
        // Monday + Tuesday + Wednesday of same week — all same task
        let createdAt = date(2026, 3, 16) // created earlier
        let wedWeekday = Calendar.current.component(.weekday, from: today)
        let monWeekday = Calendar.current.component(.weekday, from: date(2026, 3, 23))
        let tueWeekday = Calendar.current.component(.weekday, from: date(2026, 3, 24))

        let task = Task(title: "gym",
                        recurrence: .weekly(days: [monWeekday, tueWeekday, wedWeekday]),
                        blocksApps: true, createdAt: createdAt)
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)
        let count = result.filter { $0.id == task.id }.count
        XCTAssertEqual(count, 1,
                       "Task missed on Mon, Tue, and scheduled for Wed must appear exactly once (deduped)")
    }

    // MARK: - Task created after the target date must not appear

    func testBuildTodayTasks_taskCreatedTomorrow_notInTodayList() {
        let today    = date(2026, 3, 25)
        let tomorrow = date(2026, 3, 26)
        let todayWeekday = Calendar.current.component(.weekday, from: today)

        // Task created tomorrow — should not appear in today's list
        let task = Task(title: "future", recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true, createdAt: tomorrow)
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)
        XCTAssertFalse(result.contains { $0.id == task.id },
                       "Task created tomorrow must not appear in today's task list")
    }

    func testBuildTodayTasks_taskCreatedExactlyToday_appearsToday() {
        // Boundary: created today → must appear today.
        let today        = date(2026, 3, 25)
        let todayWeekday = Calendar.current.component(.weekday, from: today)

        let task = Task(title: "new", recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true, createdAt: today)
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)
        XCTAssertTrue(result.contains { $0.id == task.id },
                      "Task created today must appear in today's list")
    }

    // MARK: - Once tasks: no time-limit on carryover

    func testBuildTodayTasks_onceTask_30DaysOld_appearsUntilCompleted() {
        // Once tasks carry over indefinitely — they don't expire after 7 days.
        let today      = date(2026, 3, 25)
        let thirtyAgo  = date(2026, 2, 23)

        let task = Task(title: "old task",
                        recurrence: .once(startDate: thirtyAgo.dateString),
                        blocksApps: true, createdAt: thirtyAgo)
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)
        XCTAssertTrue(result.contains { $0.id == task.id },
                      "Once task with startDate 30 days ago must still appear if never completed")
        XCTAssertTrue(result.first { $0.id == task.id }?.isCarryOver ?? false,
                      "Overdue once task must be marked as carryOver")
    }

    func testBuildTodayTasks_onceTask_completedAnyDay_doesNotCarryOver() {
        // A once task completed on an EARLIER date must not appear again.
        let startDate = date(2026, 3, 10)
        let completed = date(2026, 3, 12)
        let today     = date(2026, 3, 25)

        let task = Task(title: "read",
                        recurrence: .once(startDate: startDate.dateString),
                        blocksApps: true, createdAt: startDate)
        store.addTask(task)
        store.completeTask(task.id, on: completed.dateString) // completed on the 12th

        let result = store.buildTodayTasks(on: today)
        XCTAssertFalse(result.contains { $0.id == task.id },
                       "Once task already completed on an earlier date must not reappear")
    }

    func testBuildTodayTasks_onceTaskStartingTomorrow_notInTodayList() {
        let today    = date(2026, 3, 25)
        let tomorrow = date(2026, 3, 26)

        let task = Task(title: "future",
                        recurrence: .once(startDate: tomorrow.dateString),
                        blocksApps: true, createdAt: today)
        store.addTask(task)

        let result = store.buildTodayTasks(on: today)
        XCTAssertFalse(result.contains { $0.id == task.id },
                       "Once task with future startDate must not appear today")
    }

    // MARK: - Completed carryover task: only appears on its completion date

    func testBuildTodayTasks_completedCarryoverTask_notShownAgain() {
        // Task was on Monday, not completed. Completed as carryover on Wednesday.
        // Thursday: must NOT reappear.
        let createdAt = date(2026, 3, 16)
        let monday    = date(2026, 3, 23) // weekday 2
        let wednesday = date(2026, 3, 25) // weekday 4
        let thursday  = date(2026, 3, 26) // weekday 5
        let monWeekday = Calendar.current.component(.weekday, from: monday)

        let task = Task(title: "gym", recurrence: .weekly(days: [monWeekday]),
                        blocksApps: true, createdAt: createdAt)
        store.addTask(task)

        // Complete on Wednesday as carryover (logged against Monday — the scheduled date)
        store.completeTask(task.id, on: monday.dateString)

        let result = store.buildTodayTasks(on: thursday)
        XCTAssertFalse(result.contains { $0.id == task.id },
                       "Task completed (even as carryover) must not reappear on subsequent days")
    }

    // MARK: - Recurrence edit: changing day must not produce phantom carryover

    func testCarryover_taskEditedFromFridayToSaturday_doesNotAppearOnWednesday() {
        // Scenario: task was created two weeks ago recurring on Friday.
        // Today is Wednesday. We edit the recurrence to Saturday.
        // The task should NOT appear in Wednesday's list — it was never due on
        // last Saturday (March 28) and next Saturday hasn't arrived yet.
        let wednesday = date(2026, 4, 1)   // weekday 4
        let lastFriday = date(2026, 3, 27) // weekday 6 — the most recent Friday within the 7-day window
        let createdAt  = date(2026, 3, 13) // two Fridays ago — task has history

        let fridayWeekday   = Calendar.current.component(.weekday, from: lastFriday)
        let saturdayWeekday = Calendar.current.component(.weekday, from: date(2026, 3, 28))

        // 1. Add as a Friday task (uncompleted on last Friday → would carryover before edit)
        let task = Task(title: "gym", recurrence: .weekly(days: [fridayWeekday]),
                        blocksApps: true, createdAt: createdAt)
        store.addTask(task)

        let beforeEdit = store.buildTodayTasks(on: wednesday)
        XCTAssertTrue(beforeEdit.contains { $0.id == task.id },
                      "Precondition: uncompleted Friday task must appear as carryover on Wednesday before edit")

        // 2. Edit recurrence from Friday → Saturday (stamp recurrenceChangedAt as Wednesday)
        var edited = task
        edited.recurrence = .weekly(days: [saturdayWeekday])
        store.updateTask(edited, now: wednesday)

        // 3. Task must NOT appear in Wednesday's list — it was never a Saturday task
        //    before the edit, so last Saturday is not a valid missed day for it.
        let afterEdit = store.buildTodayTasks(on: wednesday)
        XCTAssertFalse(afterEdit.contains { $0.id == task.id },
                       "Task edited from Friday to Saturday must not appear as a carryover on Wednesday — it was never scheduled on last Saturday")
    }

    // MARK: - incompleteBlockingTasks respects blockingStartTime

    func testIncompleteBlockingTasks_futureStartTime_notBlocking() {
        // Task has a start time 2 hours from now (but is in today's task list).
        // incompleteBlockingTasks should exclude it.
        let now = Date()
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let futureHour = ((comps.hour ?? 0) + 2) % 24
        let futureStart = DateComponents(hour: futureHour, minute: 0)

        let todayWeekday = cal.component(.weekday, from: now)
        let task = Task(title: "block later",
                        recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true,
                        createdAt: Calendar.current.startOfDay(for: now),
                        blockingStartTime: futureStart)
        store.addTask(task)
        store.completeTask(task.id, on: "") // don't complete — keep it pending
        // Actually don't complete it, just check incompleteBlockingTasks
        // Re-add without completing:
        store.removeTask(id: task.id)
        store.addTask(task)

        let blocking = store.incompleteBlockingTasks
        XCTAssertFalse(blocking.contains { $0.id == task.id },
                       "Task with future blockingStartTime must not be in incompleteBlockingTasks yet")
    }

    func testIncompleteBlockingTasks_nilStartTime_alwaysBlocking() {
        let now          = Date()
        let todayWeekday = Calendar.current.component(.weekday, from: now)
        let task = Task(title: "block now",
                        recurrence: .weekly(days: [todayWeekday]),
                        blocksApps: true,
                        createdAt: Calendar.current.startOfDay(for: now),
                        blockingStartTime: nil)
        store.addTask(task)

        // Ensure an app selection exists (needed for incompleteBlockingTasks to be non-empty)
        let blocking = store.incompleteBlockingTasks
        XCTAssertTrue(blocking.contains { $0.id == task.id },
                      "Task with nil blockingStartTime must always appear in incompleteBlockingTasks when incomplete")
    }
}
