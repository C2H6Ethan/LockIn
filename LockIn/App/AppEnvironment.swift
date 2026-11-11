import Foundation
import LockInCore
import LockInPlatform

/// The app's dependencies, built once at launch and injected. No singletons.
@MainActor
struct AppEnvironment {
    let store: LockInStore
    let enforcement: Enforcement
    let steps: StepGoalObserver

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
        return AppEnvironment(store: enforcement.storeForReading, enforcement: enforcement, steps: steps)
    }

    /// Called from `didFinishLaunching`, including background launches by HealthKit.
    func startBackgroundObservers() {
        if StepGoal.isInUse(store.read(.tasks)) { steps.start() }
    }

    /// Re-applies everything that depends on Tasks, the Blocklist or settings. Call after every change.
    func stateDidChange() {
        enforcement.refresh(reason: "state changed")
        guard StepGoal.isInUse(store.read(.tasks)) else { return }
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
