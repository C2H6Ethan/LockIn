import Foundation
import LockInCore
import Testing
@testable import LockIn

@MainActor
struct ReviewPromptAppTests {
    @Test func asksOnceWhenTheStreakHitsSeven() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!
        let store = LockInStore(storage: InMemoryStorage())
        var settings = Settings(hasCompletedOnboarding: true, firstDay: DayKey("2026-11-10")!)
        settings.streakSeed = StreakSeed(count: 7, asOf: DayKey("2026-11-09")!)
        store.write(settings, to: .settings)

        let model = TodayModel(store: store, calendar: calendar, now: { now }, onChange: {})
        #expect(model.streak == 8)  // seeded 7 through yesterday, plus today (nothing Required, so Kept)
        #expect(model.consumeReviewRequest())
        #expect(!model.consumeReviewRequest())
        #expect(store.read(.settings).hasRequestedReview)
    }
}
