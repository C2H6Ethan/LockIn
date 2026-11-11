import Foundation
import LockInCore
import LockInPlatform

/// The app's dependencies, built once at launch and injected. No singletons.
@MainActor
struct AppEnvironment {
    let store: LockInStore
    let enforcement: Enforcement

    static func live() -> AppEnvironment {
        guard let enforcement = Enforcement.live(source: .app) else {
            fatalError("App Group \(AppGroup.id) is missing from the entitlements.")
        }
        #if DEBUG
        DebugSeed.applyIfRequested(to: enforcement.storeForReading)
        #endif
        return AppEnvironment(store: enforcement.storeForReading, enforcement: enforcement)
    }

    /// Re-applies everything that depends on Tasks, the Blocklist or settings. Call after every change.
    func stateDidChange() {
        enforcement.refresh(reason: "state changed")
    }
}
