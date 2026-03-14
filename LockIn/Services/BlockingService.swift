import Foundation
import FamilyControls
import ManagedSettings

// MARK: - Protocol (enables test injection)

protocol ShieldApplying {
    func apply(selection: FamilyActivitySelection)
    func remove()
}

// MARK: - Live Applier

final class ManagedSettingsShieldApplier: ShieldApplying {
    private lazy var managedStore = ManagedSettingsStore()

    func apply(selection: FamilyActivitySelection) {
        let tokens = selection.applicationTokens
        managedStore.shield.applications = tokens.isEmpty ? nil : tokens
    }

    func remove() {
        managedStore.shield.applications = nil
    }
}

// MARK: - BlockingService

final class BlockingService {

    static let shared = BlockingService()

    private let store: SharedStore
    private let applier: any ShieldApplying
    private var unblockTask: _Concurrency.Task<Void, Never>?

    init(store: SharedStore = .shared, applier: any ShieldApplying = ManagedSettingsShieldApplier()) {
        self.store = store
        self.applier = applier
    }

    // MARK: - Public API

    /// Apply or remove shields based on current habit completion + app selection state.
    /// No-op if a temporary unblock window is still active.
    func updateShieldsForCurrentHabitState() {
        if let expires = store.unblockExpiresAt, expires > Date() { return }
        store.unblockExpiresAt = nil

        let blocking = store.incompleteBlockingTasks
        let selection = store.selectedApps
        let hasApps = !selection.applicationTokens.isEmpty

        if !blocking.isEmpty && hasApps {
            applier.apply(selection: selection)
        } else {
            applier.remove()
        }
    }

    /// Remove shields for `duration` seconds, then re-apply based on habit state.
    func temporaryUnblock(duration: TimeInterval = Constants.Bypass.defaultWindowDuration) {
        store.unblockExpiresAt = Date().addingTimeInterval(duration)
        applier.remove()

        unblockTask?.cancel()
        unblockTask = _Concurrency.Task { [weak self] in
            try? await _Concurrency.Task.sleep(for: .seconds(duration))
            guard let self, !_Concurrency.Task.isCancelled else { return }
            await MainActor.run {
                self.store.unblockExpiresAt = nil
                self.updateShieldsForCurrentHabitState()
            }
        }
    }
}
