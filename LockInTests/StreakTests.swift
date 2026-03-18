import XCTest
@testable import LockIn

final class StreakTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.streak.\(UUID().uuidString)")
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    private func addBlockingTask(on weekday: Int) -> Task {
        let task = Task(title: "Run", activeDays: [weekday], blocksApps: true)
        store.addTask(task)
        return task
    }

    // MARK: - updateStreak: first completion

    func testUpdateStreak_firstCompletion_setsStreakToOne() {
        let date = makeDate(year: 2026, month: 3, day: 11) // Wednesday, weekday 4
        let task = addBlockingTask(on: 4)
        store.completeTask(task.id, on: date.dateString)

        store.updateStreak(for: date.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 1)
        XCTAssertEqual(store.streakData.lastCompletedDate, date.dateString)
    }

    func testUpdateStreak_consecutiveDay_incrementsStreak() {
        // Day 1: Mar 10 (Tuesday, weekday 3)
        let day1 = makeDate(year: 2026, month: 3, day: 10)
        let day1Task = addBlockingTask(on: 3)
        store.completeTask(day1Task.id, on: day1.dateString)
        store.updateStreak(for: day1.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Day 2: Mar 11 (Wednesday, weekday 4)
        let day2 = makeDate(year: 2026, month: 3, day: 11)
        let day2Task = addBlockingTask(on: 4)
        store.completeTask(day2Task.id, on: day2.dateString)
        store.updateStreak(for: day2.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 2)
        XCTAssertEqual(store.streakData.longestStreak, 2)
    }

    func testUpdateStreak_gapBetweenDays_resetsToOne() {
        // Day 1: Mar 9 (Monday, weekday 2)
        let day1 = makeDate(year: 2026, month: 3, day: 9)
        let day1Task = addBlockingTask(on: 2)
        store.completeTask(day1Task.id, on: day1.dateString)
        store.updateStreak(for: day1.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Day 2: Mar 11 (Wednesday, weekday 4) — Tuesday (weekday 3) has a blocking task → real gap
        let day2 = makeDate(year: 2026, month: 3, day: 11)
        let _ = addBlockingTask(on: 3) // Tuesday blocking task, never completed
        let day2Task = addBlockingTask(on: 4)
        store.completeTask(day2Task.id, on: day2.dateString)
        store.updateStreak(for: day2.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 1)
    }

    func testUpdateStreak_gapOfTaskFreeDays_continuesStreak() {
        // Monday task completed → streak 1
        // Tuesday: no tasks (free day)
        // Wednesday task completed → streak should be 2, not reset
        let monday = makeDate(year: 2026, month: 3, day: 9)   // weekday 2
        let wednesday = makeDate(year: 2026, month: 3, day: 11) // weekday 4

        let monTask = addBlockingTask(on: 2)
        let wedTask = addBlockingTask(on: 4)
        // No task on Tuesday (weekday 3)

        store.completeTask(monTask.id, on: monday.dateString)
        store.updateStreak(for: monday.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        store.completeTask(wedTask.id, on: wednesday.dateString)
        store.updateStreak(for: wednesday.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 2)
    }

    func testUpdateStreak_mondayToSunday_streakIsTwo() {
        // Tasks only on Monday and Sunday — 5 free days in between.
        // Completing both should give streak = 2.
        let monday = makeDate(year: 2026, month: 3, day: 9)  // weekday 2
        let sunday = makeDate(year: 2026, month: 3, day: 15) // weekday 1

        let monTask = addBlockingTask(on: 2)
        let sunTask = addBlockingTask(on: 1)
        // No tasks Tue–Sat (weekdays 3–7)

        store.completeTask(monTask.id, on: monday.dateString)
        store.updateStreak(for: monday.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        store.completeTask(sunTask.id, on: sunday.dateString)
        store.updateStreak(for: sunday.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 2)
    }

    func testUpdateStreak_sameDayCalledTwice_idempotent() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        let task = addBlockingTask(on: 4)
        store.completeTask(task.id, on: date.dateString)

        store.updateStreak(for: date.dateString)
        store.updateStreak(for: date.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 1)
    }

    func testUpdateStreak_nonBlockingTaskCompleted_incrementsStreak() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        // Non-blocking task (e.g. flossing) — completed counts toward streak
        let task = Task(title: "Floss", activeDays: [4], blocksApps: false)
        store.addTask(task)
        store.completeTask(task.id, on: date.dateString)

        store.updateStreak(for: date.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 1)
    }

    func testUpdateStreak_notAllBlockingCompleted_noChange() {
        let date = makeDate(year: 2026, month: 3, day: 11)
        let task1 = addBlockingTask(on: 4)
        let _ = addBlockingTask(on: 4) // task2 not completed
        store.completeTask(task1.id, on: date.dateString)

        store.updateStreak(for: date.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testUpdateStreak_updatesLongestStreak() {
        // Simulate a 3-day streak
        let days: [(Int, Int, Int, Int)] = [
            (2026, 3, 9, 2),  // Mon
            (2026, 3, 10, 3), // Tue
            (2026, 3, 11, 4), // Wed
        ]
        for (year, month, day, weekday) in days {
            let date = makeDate(year: year, month: month, day: day)
            let task = addBlockingTask(on: weekday)
            store.completeTask(task.id, on: date.dateString)
            store.updateStreak(for: date.dateString)
        }

        XCTAssertEqual(store.streakData.currentStreak, 3)
        XCTAssertEqual(store.streakData.longestStreak, 3)
    }

    func testUpdateStreak_longestStreak_doesNotDecreaseOnReset() {
        // Build streak of 2
        let day1 = makeDate(year: 2026, month: 3, day: 9)
        let t1 = addBlockingTask(on: 2)
        store.completeTask(t1.id, on: day1.dateString)
        store.updateStreak(for: day1.dateString)

        let day2 = makeDate(year: 2026, month: 3, day: 10)
        let t2 = addBlockingTask(on: 3)
        store.completeTask(t2.id, on: day2.dateString)
        store.updateStreak(for: day2.dateString)
        XCTAssertEqual(store.streakData.longestStreak, 2)

        // Gap → streak resets but longestStreak stays
        let day3 = makeDate(year: 2026, month: 3, day: 12) // skipped Mar 11
        let _ = addBlockingTask(on: 4) // Wed (Mar 11) blocking task, never completed → real gap
        let t3 = addBlockingTask(on: 5)
        store.completeTask(t3.id, on: day3.dateString)
        store.updateStreak(for: day3.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 1)
        XCTAssertEqual(store.streakData.longestStreak, 2)
    }

    // MARK: - checkAndUpdateStreak

    func testCheckAndUpdateStreak_noLastDate_noChange() {
        addBlockingTask(on: 4)
        let today = makeDate(year: 2026, month: 3, day: 11)
        store.checkAndUpdateStreak(today: today)
        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testCheckAndUpdateStreak_lastDateIsToday_noChange() {
        let today = makeDate(year: 2026, month: 3, day: 11)
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5, lastCompletedDate: today.dateString)
        store.checkAndUpdateStreak(today: today)
        XCTAssertEqual(store.streakData.currentStreak, 5)
    }

    func testCheckAndUpdateStreak_lastDateIsYesterday_noChange() {
        let today = makeDate(year: 2026, month: 3, day: 11)
        let yesterday = makeDate(year: 2026, month: 3, day: 10)
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: yesterday.dateString)
        store.checkAndUpdateStreak(today: today)
        XCTAssertEqual(store.streakData.currentStreak, 3)
    }

    func testCheckAndUpdateStreak_missedDayWithBlockingTask_resetsStreak() {
        // Last completed: Mar 9 (Mon). Today: Mar 11 (Wed).
        // Mar 10 (Tue) had a blocking task that wasn't completed → break streak
        let today = makeDate(year: 2026, month: 3, day: 11)
        let lastCompleted = makeDate(year: 2026, month: 3, day: 9)
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5, lastCompletedDate: lastCompleted.dateString)
        // Drain freeze so streak resets immediately (no offer prompt)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString
        addBlockingTask(on: 3) // Tuesday task, never completed
        store.checkAndUpdateStreak(today: today)
        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testCheckAndUpdateStreak_missedDayWithNonBlockingTask_resetsStreak() {
        // Non-blocking missed task should break streak just like a blocking one
        let today = makeDate(year: 2026, month: 3, day: 11)
        let lastCompleted = makeDate(year: 2026, month: 3, day: 9)
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5, lastCompletedDate: lastCompleted.dateString)
        // Drain freeze so streak resets immediately (no offer prompt)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString
        let task = Task(title: "Floss", activeDays: [3], blocksApps: false) // Tuesday, never completed
        store.addTask(task)
        store.checkAndUpdateStreak(today: today)
        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testCheckAndUpdateStreak_missedDayNoTasks_keepStreak() {
        // Last completed: Mar 9 (Mon). Today: Mar 11 (Wed).
        // Mar 10 (Tue) had no tasks at all → streak intact
        let today = makeDate(year: 2026, month: 3, day: 11)
        let lastCompleted = makeDate(year: 2026, month: 3, day: 9)
        store.streakData = StreakData(currentStreak: 4, longestStreak: 4, lastCompletedDate: lastCompleted.dateString)
        addBlockingTask(on: 4) // Wednesday only, no Tuesday task
        store.checkAndUpdateStreak(today: today)
        XCTAssertEqual(store.streakData.currentStreak, 4)
    }

    func testCheckAndUpdateStreak_zeroCurrent_noChange() {
        let today = makeDate(year: 2026, month: 3, day: 11)
        let old = makeDate(year: 2026, month: 3, day: 1)
        store.streakData = StreakData(currentStreak: 0, longestStreak: 5, lastCompletedDate: old.dateString)
        addBlockingTask(on: 2) // Mon blocking task, not completed
        store.checkAndUpdateStreak(today: today)
        XCTAssertEqual(store.streakData.currentStreak, 0) // already 0, no change needed
    }

    // MARK: - checkAndUpdateStreak: once tasks (regression for once-task blind spot)

    func testCheckAndUpdateStreak_missedOnceTask_resetsStreak() {
        // Bug: once tasks have activeDays=[] so the old scanner never detected them as missed.
        // streak = 3, lastCompleted = Mar 9. Mar 10 had a once task, never completed → should reset.
        let today = makeDate(year: 2026, month: 3, day: 11)          // Wed
        let yesterday = makeDate(year: 2026, month: 3, day: 10)      // Tue
        let twoDaysAgo = makeDate(year: 2026, month: 3, day: 9)      // Mon
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: twoDaysAgo.dateString)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString

        let task = Task(title: "Write", recurrence: .once(startDate: yesterday.dateString), blocksApps: true)
        store.addTask(task)

        store.checkAndUpdateStreak(today: today)

        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testCheckAndUpdateStreak_completedOnceTask_keepStreak() {
        // A once task started yesterday but WAS completed yesterday → not a missed day, streak intact.
        let today = makeDate(year: 2026, month: 3, day: 11)
        let yesterday = makeDate(year: 2026, month: 3, day: 10)
        let twoDaysAgo = makeDate(year: 2026, month: 3, day: 9)
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: twoDaysAgo.dateString)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString

        let task = Task(title: "Write", recurrence: .once(startDate: yesterday.dateString), blocksApps: true)
        store.addTask(task)
        store.completeTask(task.id, on: yesterday.dateString)

        store.checkAndUpdateStreak(today: today)

        XCTAssertEqual(store.streakData.currentStreak, 3)
    }

    func testCheckAndUpdateStreak_missedOnceTask_offersFreezeWhenAvailable() {
        // One missed day with a once task + freeze available → offer freeze, don't reset yet.
        let today = makeDate(year: 2026, month: 3, day: 11)
        let yesterday = makeDate(year: 2026, month: 3, day: 10)
        let twoDaysAgo = makeDate(year: 2026, month: 3, day: 9)
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: twoDaysAgo.dateString)
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = today.isoWeekString

        let task = Task(title: "Write", recurrence: .once(startDate: yesterday.dateString), blocksApps: true)
        store.addTask(task)

        store.checkAndUpdateStreak(today: today)

        XCTAssertTrue(store.pendingFreezeOffer)
        XCTAssertEqual(store.streakData.currentStreak, 3) // held pending freeze decision
    }

    func testCheckAndUpdateStreak_onceTaskStartedTwoDaysAgo_stillCountsAsMissed() {
        // A once task that started 2 days ago and was never completed counts as missed
        // on its start date, not just on the immediately preceding day.
        let today = makeDate(year: 2026, month: 3, day: 12)         // Thu
        let threeDaysAgo = makeDate(year: 2026, month: 3, day: 9)   // Mon — last completed
        let twoDaysAgo = makeDate(year: 2026, month: 3, day: 10)    // Tue — once task start
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5, lastCompletedDate: threeDaysAgo.dateString)
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = today.isoWeekString

        let task = Task(title: "Read", recurrence: .once(startDate: twoDaysAgo.dateString), blocksApps: true)
        store.addTask(task)

        store.checkAndUpdateStreak(today: today)

        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    // MARK: - updateStreak: gap check with once tasks (regression)

    func testUpdateStreak_gapContainsOnceTask_resetsToOne() {
        // Bug: old gap check used activeDays only, so once tasks were invisible.
        // Mon: completed weekly task → streak 1.
        // Tue: once task starts (in the gap), never completed that day.
        // Thu: complete both the weekly Thu task and the once task carryover.
        // Gap (Tue) had a once task → gapIsAllFree must be false → streak resets to 1, not 2.
        let monday   = makeDate(year: 2026, month: 3, day: 9)   // weekday 2
        let tuesday  = makeDate(year: 2026, month: 3, day: 10)  // weekday 3
        let thursday = makeDate(year: 2026, month: 3, day: 12)  // weekday 5

        let monTask = addBlockingTask(on: 2)
        store.completeTask(monTask.id, on: monday.dateString)
        store.updateStreak(for: monday.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Once task starts Tuesday — not completed Tuesday, carried over to Thursday
        let onceTask = Task(title: "Read", recurrence: .once(startDate: tuesday.dateString), blocksApps: true)
        store.addTask(onceTask)

        // Thursday: complete both the weekly task and the once task carryover
        let thuTask = addBlockingTask(on: 5)
        store.completeTask(thuTask.id, on: thursday.dateString)
        store.completeTask(onceTask.id, on: thursday.dateString)

        store.updateStreak(for: thursday.dateString)

        // Gap day (Tue) had a once task → not a free gap → streak is 1, not 2
        XCTAssertEqual(store.streakData.currentStreak, 1)
    }

    func testUpdateStreak_gapContainsOnlyFreeOnce_noTask_extendsStreak() {
        // Control: gap with NO once tasks (and no weekly tasks) → streak extends normally.
        let monday   = makeDate(year: 2026, month: 3, day: 9)   // weekday 2
        let thursday = makeDate(year: 2026, month: 3, day: 12)  // weekday 5

        let monTask = addBlockingTask(on: 2)
        store.completeTask(monTask.id, on: monday.dateString)
        store.updateStreak(for: monday.dateString)
        XCTAssertEqual(store.streakData.currentStreak, 1)

        // Thursday task — Tue/Wed have no tasks at all
        let thuTask = addBlockingTask(on: 5)
        store.completeTask(thuTask.id, on: thursday.dateString)
        store.updateStreak(for: thursday.dateString)

        XCTAssertEqual(store.streakData.currentStreak, 2)
    }
}
