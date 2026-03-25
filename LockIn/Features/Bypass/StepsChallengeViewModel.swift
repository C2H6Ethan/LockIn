import Foundation
import CoreMotion

@Observable
final class StepsChallengeViewModel {

    // MARK: - Public state

    var stepCount: Int = 0
    var isComplete: Bool = false
    var motionDenied: Bool = false

    let goal: Int

    // MARK: - Private

    private let store: SharedStore
    private let pedometer = CMPedometer()
    private var isTracking = false

    // MARK: - Init

    init(store: SharedStore = .shared) {
        self.store = store
        self.goal = store.stepsRequired
    }

    // MARK: - Tracking

    func startTracking() {
        guard CMPedometer.isStepCountingAvailable(), !isTracking else { return }
        isTracking = true

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self else { return }

            if error != nil && data == nil {
                _Concurrency.Task { @MainActor in self.motionDenied = true }
                return
            }

            guard let data else { return }
            let steps = data.numberOfSteps.intValue

            _Concurrency.Task { @MainActor in
                self.stepCount = steps
                if steps >= self.goal {
                    self.completeChallenge()
                }
            }
        }
    }

    func stopTracking() {
        pedometer.stopUpdates()
        isTracking = false
    }

    private func completeChallenge() {
        guard !isComplete else { return }
        isComplete = true
        store.recordBypassUsed()
        let duration = TimeInterval(Constants.Stepping.accessWindowMinutes * 60)
        BlockingService.shared.temporaryUnblock(duration: duration)
        ActivityLog.log("BYPASS_STARTED: \(Constants.Stepping.accessWindowMinutes)min window, bypassCount=\(store.bypassCountToday)")
    }
}
