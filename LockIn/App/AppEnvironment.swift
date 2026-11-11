import Foundation
import LockInCore
import LockInPlatform

/// The app's dependencies, built once at launch and injected. No singletons.
@MainActor
struct AppEnvironment {
    let store: LockInStore
    let enforcement: Enforcement
    let steps: StepGoalObserver
    let places: PlaceMonitor

    static func live() -> AppEnvironment {
        guard let enforcement = Enforcement.live(source: .app) else {
            fatalError("App Group \(AppGroup.id) is missing from the entitlements.")
        }
        #if DEBUG
        DebugSeed.applyIfRequested(to: enforcement.storeForReading)
        #endif
        // HealthKit calls back on its own queue; a fresh Enforcement over the App Group is cheap and Sendable-safe.
        let steps = StepGoalObserver { total in
            Enforcement.live(source: .app)?.recordSteps(total)
        }
        let places = PlaceMonitor { id in
            Enforcement.live(source: .app)?.recordVisit(id)
        }
        return AppEnvironment(store: enforcement.storeForReading, enforcement: enforcement, steps: steps, places: places)
    }

    /// Called from `didFinishLaunching`, including background launches by HealthKit.
    func startBackgroundObservers() {
        let tasks = store.read(.tasks)
        if StepGoal.isInUse(tasks) { steps.start() }
        places.sync(tasks: tasks)
    }

    /// Asks HealthKit for today's steps now, instead of waiting for background delivery (at most hourly,
    /// never while locked, never after a force-quit). `onCompleted` runs on the main actor if a
    /// Step-Goal Task was completed.
    func refreshSteps(onCompleted: @escaping @MainActor @Sendable () -> Void = {}) {
        guard StepGoal.isInUse(store.read(.tasks)) else { return }
        steps.stepsToday { total in
            guard let total, Enforcement.live(source: .app)?.recordSteps(total) == true else { return }
            Task { @MainActor in onCompleted() }
        }
    }

    /// Re-applies everything that depends on Tasks, the Blocklist or settings. Call after every change.
    func stateDidChange() {
        enforcement.refresh(reason: "state changed")
        let tasks = store.read(.tasks)
        if tasks.contains(where: { $0.place != nil }) { places.requestAuthorization() }
        places.sync(tasks: tasks)
        guard StepGoal.isInUse(tasks) else { return }
        // The first Step-Goal Task asks for HealthKit access; then today's steps may already complete it.
        let steps = steps
        Task {
            await steps.requestAuthorization()
            steps.start()
            steps.stepsToday { total in
                if let total { Enforcement.live(source: .app)?.recordSteps(total) }
            }
        }
    }
}
