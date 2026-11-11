import Foundation
import LockInCore
import LockInPlatform

/// The app's dependencies, built once at launch and injected. No singletons.
@MainActor
struct AppEnvironment {
    let store: LockInStore
    let shieldEnforcer: ShieldEnforcer

    static func live() -> AppEnvironment {
        guard let storage = UserDefaultsStorage.appGroup() else {
            fatalError("App Group \(AppGroup.id) is missing from the entitlements.")
        }
        let store = LockInStore(storage: storage)
        return AppEnvironment(store: store, shieldEnforcer: ShieldEnforcer(store: store, applier: .live()))
    }

    /// Re-applies everything that depends on Tasks, the Blocklist or settings. Call after every change.
    func stateDidChange() {
        shieldEnforcer.reevaluate()
    }
}
