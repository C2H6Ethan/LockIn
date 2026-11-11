import Foundation
import LockInCore
import Testing
@testable import LockIn

@MainActor
struct OnboardingModelTests {
    var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Zurich")!
        return c
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }

    func model(store: LockInStore = LockInStore(storage: InMemoryStorage()), authorizes: Bool = true, onFinish: @escaping () -> Void = {}) -> OnboardingModel {
        OnboardingModel(
            store: store,
            calendar: calendar,
            now: { now },
            requestScreenTime: { authorizes },
            requestNotifications: {},
            onFinish: onFinish
        )
    }

    @Test func stepsRunInOrder() async {
        let m = model()
        #expect(m.step == .welcome)
        await m.continue()
        #expect(m.step == .screenTime)
        await m.continue()
        #expect(m.step == .blocklist)
        await m.continue()
        #expect(m.step == .firstTask)
        await m.continue()
        #expect(m.step == .notifications)
        await m.continue()
        #expect(m.step == .done)
    }

    @Test func deniedScreenTimeStaysOnTheStepWithAnExplanation() async {
        let m = model(authorizes: false)
        await m.continue()
        await m.continue()
        #expect(m.step == .screenTime)
        #expect(m.screenTimeDenied)
    }

    @Test func finishingRecordsTheFirstDayAndNotifies() async {
        let store = LockInStore(storage: InMemoryStorage())
        var finished = 0
        let m = model(store: store, onFinish: { finished += 1 })
        for _ in 0..<5 { await m.continue() }
        m.finish()
        let settings = store.read(.settings)
        #expect(settings.hasCompletedOnboarding)
        #expect(settings.firstDay == DayKey("2026-11-10"))
        #expect(finished == 1)
    }

    @Test func doneCopyReflectsWhetherATaskWasAdded() async {
        let store = LockInStore(storage: InMemoryStorage())
        let m = model(store: store)
        #expect(m.doneSubtitle == "Add a task whenever you're ready. Until then nothing is blocked.")
        store.write([LockInTask(title: "Read", schedule: .weekly(Set(Weekday.allCases)), requirement: .required, createdOn: DayKey("2026-11-10")!)], to: .tasks)
        #expect(m.doneSubtitle == "Your apps stay blocked until your required tasks are done.")
    }
}
