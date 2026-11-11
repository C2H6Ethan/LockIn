import Foundation
import LockInCore
import LockInPlatform
import Testing

@MainActor
struct ReminderTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var evening: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 20))! }

    func enforcement(_ store: LockInStore, _ poster: FakePoster, _ center: FakeActivityCenter = FakeActivityCenter()) -> Enforcement {
        Enforcement(
            store: store,
            registrar: ScheduleRegistrar(center: center),
            enforcer: ShieldEnforcer(store: store, applier: ShieldApplier(target: FakeShieldTarget()), calendar: calendar),
            poster: poster,
            calendar: calendar,
            source: .monitor
        )
    }

    @Test func postsWhenRequiredTasksAreOwed() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-01")!)], to: .tasks)
        let poster = FakePoster()
        enforcement(store, poster).intervalDidStart(activityName: "reminder-2000", now: evening)
        #expect(poster.posts.map(\.title) == ["Read is still open"])
        #expect(poster.posts.first?.id == "reminder")
        #expect(poster.posts.first?.deepLink == URL(string: "lockin://today"))
    }

    @Test func staysQuietWhenNothingIsOwed() {
        let store = LockInStore(storage: InMemoryStorage())
        let poster = FakePoster()
        enforcement(store, poster).intervalDidStart(activityName: "reminder-2000", now: evening)
        #expect(poster.posts.isEmpty)
        #expect(store.read(.eventLog).events.last?.message == "Reminder skipped: nothing owed")
    }

    @Test func otherActivitiesNeverPostAReminder() {
        let store = LockInStore(storage: InMemoryStorage())
        store.write([LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-01")!)], to: .tasks)
        let poster = FakePoster()
        enforcement(store, poster).intervalDidStart(activityName: "day", now: evening)
        #expect(poster.posts.isEmpty)
    }

    @Test func reminderActivityFollowsTheSetting() {
        let store = LockInStore(storage: InMemoryStorage())
        let center = FakeActivityCenter()
        enforcement(store, FakePoster(), center).refresh(reason: "test", now: evening)
        #expect(Set(center.registered.keys) == ["day", "reminder-2000"])
        store.write(Settings(reminderTime: nil), to: .settings)
        enforcement(store, FakePoster(), center).refresh(reason: "test", now: evening)
        #expect(Set(center.registered.keys) == ["day"])
    }
}

final class FakePoster: NotificationPoster {
    struct Post { let id: String; let title: String; let body: String; let deepLink: URL? }
    var posts: [Post] = []
    func post(id: String, title: String, body: String, deepLink: URL?) {
        posts.append(Post(id: id, title: title, body: body, deepLink: deepLink))
    }
}
