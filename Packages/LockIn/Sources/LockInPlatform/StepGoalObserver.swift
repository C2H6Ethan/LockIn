#if os(iOS)
import Foundation
import HealthKit
import LockInCore

/// Watches HealthKit step counts, including while LockIn isn't running: with background delivery, the
/// system wakes the app on new samples (allowed by ADR 0001, which is about the *user* opening it).
/// Must be started in `didFinishLaunching` so background launches re-register the query.
public final class StepGoalObserver: @unchecked Sendable {
    private let health = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let lock = NSLock()
    private var query: HKObserverQuery?
    private let onSteps: @Sendable (Int) -> Void

    /// `onSteps` receives today's total step count, on a background queue.
    public init(onSteps: @escaping @Sendable (Int) -> Void) {
        self.onSteps = onSteps
    }

    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows the HealthKit sheet the first time; later calls return immediately.
    public func requestAuthorization() async {
        guard Self.isAvailable else { return }
        try? await health.requestAuthorization(toShare: [], read: [stepType])
    }

    /// Registers the observer query and background delivery once per process. Idempotent.
    public func start() {
        guard Self.isAvailable else { return }
        lock.lock()
        defer { lock.unlock() }
        guard query == nil else { return }
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self, error == nil else {
                completionHandler()
                return
            }
            self.stepsToday { steps in
                if let steps { self.onSteps(steps) }
                completionHandler()
            }
        }
        self.query = query
        health.execute(query)
        health.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    }

    /// Today's total, or `nil` if HealthKit can't answer (e.g. the device is locked).
    public func stepsToday(completion: @escaping @Sendable (Int?) -> Void) {
        let now = Date()
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.startOfDay(for: now), end: now)
        let statistics = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard error == nil else { return completion(nil) }
            completion(Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0))
        }
        health.execute(statistics)
    }
}
#endif
