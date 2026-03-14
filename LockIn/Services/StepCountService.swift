import Foundation
import HealthKit

// MARK: - Protocol (enables test injection)

protocol StepProviding {
    var isAvailable: Bool { get }
    func stepsToday() async -> Int
    func startObserving(onChange: @escaping () -> Void)
    func stopObserving()
}

// MARK: - Live service

final class StepCountService: StepProviding {

    static let shared = StepCountService()

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        let stepType = HKQuantityType(.stepCount)
        try await healthStore.requestAuthorization(toShare: [], read: [stepType])
    }

    // MARK: - StepProviding

    func stepsToday() async -> Int {
        guard isAvailable else { return 0 }
        let stepType = HKQuantityType(.stepCount)
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    func startObserving(onChange: @escaping () -> Void) {
        guard isAvailable else { return }
        stopObserving()

        let stepType = HKQuantityType(.stepCount)
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completionHandler, error in
            guard error == nil else { return }
            onChange()
            completionHandler()
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    }

    func stopObserving() {
        if let query = observerQuery {
            healthStore.stop(query)
            observerQuery = nil
        }
    }
}
