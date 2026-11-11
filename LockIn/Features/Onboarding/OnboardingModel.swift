import Foundation
import LockInCore
import Observation

/// The first-run flow. It can't finish without Screen Time access, because without it nothing can be blocked.
@MainActor
@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable { case welcome, screenTime, blocklist, firstTask, notifications, done }

    private(set) var step: Step = .welcome
    private(set) var screenTimeDenied = false
    private(set) var isWorking = false

    let store: LockInStore
    private let calendar: Calendar
    private let now: () -> Date
    private let requestScreenTime: () async -> Bool
    private let requestNotifications: () async -> Void
    private let onFinish: () -> Void

    init(
        store: LockInStore,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        requestScreenTime: @escaping () async -> Bool,
        requestNotifications: @escaping () async -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.store = store
        self.calendar = calendar
        self.now = now
        self.requestScreenTime = requestScreenTime
        self.requestNotifications = requestNotifications
        self.onFinish = onFinish
    }

    /// The primary action of the current step.
    func `continue`() async {
        isWorking = true
        defer { isWorking = false }
        switch step {
        case .welcome:
            step = .screenTime
        case .screenTime:
            screenTimeDenied = !(await requestScreenTime())
            if !screenTimeDenied { step = .blocklist }
        case .blocklist:
            step = .firstTask
        case .firstTask:
            step = .notifications
        case .notifications:
            await requestNotifications()
            step = .done
        case .done:
            break
        }
    }

    var hasTasks: Bool { !store.read(.tasks).isEmpty }

    var doneSubtitle: String {
        hasTasks
            ? "Your apps stay blocked until your required tasks are done."
            : "Add a task whenever you're ready. Until then nothing is blocked."
    }

    func finish() {
        var settings = store.read(.settings)
        settings.hasCompletedOnboarding = true
        settings.firstDay = settings.firstDay ?? DayKey(now(), calendar: calendar)
        store.write(settings, to: .settings)
        onFinish()
    }
}
