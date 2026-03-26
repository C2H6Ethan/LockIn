import XCTest
@testable import LockIn

final class StreakFreezeTests: XCTestCase {

    var store: SharedStore!

    override func setUp() {
        super.setUp()
        store = SharedStore(suiteName: "test.freeze.\(UUID().uuidString)")
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

    // MARK: - isoWeekString

    func testIsoWeekString_sameDay_sameString() {
        let d1 = makeDate(year: 2026, month: 3, day: 11) // Wed
        let d2 = makeDate(year: 2026, month: 3, day: 11)
        XCTAssertEqual(d1.isoWeekString, d2.isoWeekString)
    }

    func testIsoWeekString_mondayAndSunday_sameWeek() {
        let monday = makeDate(year: 2026, month: 3, day: 9)
        let sunday = makeDate(year: 2026, month: 3, day: 15)
        XCTAssertEqual(monday.isoWeekString, sunday.isoWeekString)
    }

    func testIsoWeekString_sundayToNextMonday_differentWeek() {
        let sunday = makeDate(year: 2026, month: 3, day: 15)
        let nextMonday = makeDate(year: 2026, month: 3, day: 16)
        XCTAssertNotEqual(sunday.isoWeekString, nextMonday.isoWeekString)
    }

    // MARK: - streakFreezeAvailable / resetFreezeIfNewWeek

    func testFreezeAvailable_freshStore_isTrue() {
        // New store has no stored week string → resets to 1 → available
        XCTAssertTrue(store.streakFreezeAvailable)
    }

    func testFreezeAvailable_afterConsumed_isFalse() {
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = Date().isoWeekString
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: makeDate(year: 2026, month: 3, day: 9).dateString)
        store.pendingFreezeOffer = true
        store.consumeFreeze()
        XCTAssertFalse(store.streakFreezeAvailable)
    }

    func testFreezeAvailable_newWeek_resetsToTrue() {
        // Simulate freeze already consumed last week
        store.streakFreezeCount = 0
        let lastWeek = makeDate(year: 2026, month: 3, day: 2) // previous week
        store.streakFreezeWeekString = lastWeek.isoWeekString
        // Current week is different → should reset to 1
        XCTAssertTrue(store.streakFreezeAvailable)
        XCTAssertEqual(store.streakFreezeCount, 1)
    }

    func testFreezeAvailable_sameWeek_doesNotReset() {
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = Date().isoWeekString
        XCTAssertFalse(store.streakFreezeAvailable)
        XCTAssertEqual(store.streakFreezeCount, 0)
    }

    // MARK: - consumeFreeze

    func testConsumeFreeze_patchesLastCompletedDateToYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5, lastCompletedDate: makeDate(year: 2026, month: 3, day: 9).dateString)
        store.pendingFreezeOffer = true

        store.consumeFreeze()

        XCTAssertEqual(store.streakData.lastCompletedDate, yesterday.dateString)
    }

    func testConsumeFreeze_preservesCurrentStreak() {
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5, lastCompletedDate: makeDate(year: 2026, month: 3, day: 9).dateString)
        store.pendingFreezeOffer = true

        store.consumeFreeze()

        XCTAssertEqual(store.streakData.currentStreak, 5)
    }

    func testConsumeFreeze_decrementsCount() {
        store.streakFreezeCount = 1
        store.streakFreezeWeekString = Date().isoWeekString
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: makeDate(year: 2026, month: 3, day: 9).dateString)
        store.pendingFreezeOffer = true

        store.consumeFreeze()

        XCTAssertEqual(store.streakFreezeCount, 0)
    }

    func testConsumeFreeze_clearsPendingOffer() {
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: makeDate(year: 2026, month: 3, day: 9).dateString)
        store.pendingFreezeOffer = true

        store.consumeFreeze()

        XCTAssertFalse(store.pendingFreezeOffer)
    }

    // MARK: - declineFreeze

    func testDeclineFreeze_resetsStreakToZero() {
        store.streakData = StreakData(currentStreak: 5, longestStreak: 5, lastCompletedDate: makeDate(year: 2026, month: 3, day: 9).dateString)
        store.pendingFreezeOffer = true

        store.declineFreeze()

        XCTAssertEqual(store.streakData.currentStreak, 0)
        XCTAssertNil(store.streakData.lastCompletedDate)
    }

    func testDeclineFreeze_clearsPendingOffer() {
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: makeDate(year: 2026, month: 3, day: 9).dateString)
        store.pendingFreezeOffer = true

        store.declineFreeze()

        XCTAssertFalse(store.pendingFreezeOffer)
    }

    func testDeclineFreeze_preservesLongestStreak() {
        store.streakData = StreakData(currentStreak: 5, longestStreak: 10, lastCompletedDate: makeDate(year: 2026, month: 3, day: 9).dateString)
        store.pendingFreezeOffer = true

        store.declineFreeze()

        XCTAssertEqual(store.streakData.longestStreak, 10)
    }

    // MARK: - checkAndUpdateStreak with freeze

    func testCheckAndUpdateStreak_missedDay_freezeAvailable_setsPendingOffer() {
        // Last completed Monday, today is Wednesday, Tuesday had a blocking task
        let monday = makeDate(year: 2026, month: 3, day: 9)
        let wednesday = makeDate(year: 2026, month: 3, day: 11)
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: monday.dateString)
        store.addTask(Task(title: "Run", activeDays: [3], blocksApps: true, createdAt: monday)) // Tuesday task, not completed

        store.checkAndUpdateStreak(today: wednesday)

        XCTAssertTrue(store.pendingFreezeOffer)
        XCTAssertEqual(store.streakData.currentStreak, 3) // not reset yet
    }

    func testCheckAndUpdateStreak_missedDay_noFreezeAvailable_resetsImmediately() {
        let monday = makeDate(year: 2026, month: 3, day: 9)
        let wednesday = makeDate(year: 2026, month: 3, day: 11)
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: monday.dateString)
        store.addTask(Task(title: "Run", activeDays: [3], blocksApps: true, createdAt: monday))
        // Consume the freeze so none available
        store.streakFreezeCount = 0
        store.streakFreezeWeekString = wednesday.isoWeekString

        store.checkAndUpdateStreak(today: wednesday)

        XCTAssertFalse(store.pendingFreezeOffer)
        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testCheckAndUpdateStreak_noMissedDay_noPendingOffer() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: yesterday.dateString)

        store.checkAndUpdateStreak(today: Date())

        XCTAssertFalse(store.pendingFreezeOffer)
        XCTAssertEqual(store.streakData.currentStreak, 3)
    }

    func testCheckAndUpdateStreak_twoDaysMissed_noFreezeOffer() {
        // Last Sunday, today Thursday, BOTH Monday AND Wednesday had missed tasks
        // Two missed days → freeze must NOT be offered even if available
        let sunday    = makeDate(year: 2026, month: 3, day: 8)   // weekday 1
        let thursday  = makeDate(year: 2026, month: 3, day: 12)  // weekday 5
        store.streakData = StreakData(currentStreak: 3, longestStreak: 3, lastCompletedDate: sunday.dateString)
        store.addTask(Task(title: "Mon Task", activeDays: [2], blocksApps: true, createdAt: sunday)) // weekday 2 = Mon
        store.addTask(Task(title: "Wed Task", activeDays: [4], blocksApps: true, createdAt: sunday)) // weekday 4 = Wed
        // Freeze is available (fresh store resets to 1)

        store.checkAndUpdateStreak(today: thursday)

        XCTAssertFalse(store.pendingFreezeOffer) // can't freeze 2 missed days
        XCTAssertEqual(store.streakData.currentStreak, 0)
    }

    func testCheckAndUpdateStreak_zeroCurrent_noPendingOffer() {
        let monday = makeDate(year: 2026, month: 3, day: 9)
        let wednesday = makeDate(year: 2026, month: 3, day: 11)
        store.streakData = StreakData(currentStreak: 0, longestStreak: 5, lastCompletedDate: monday.dateString)
        store.addTask(Task(title: "Run", activeDays: [3], blocksApps: true))

        store.checkAndUpdateStreak(today: wednesday)

        XCTAssertFalse(store.pendingFreezeOffer)
    }
}
