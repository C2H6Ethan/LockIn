#if os(iOS)
import CoreMotion
import Foundation

/// Live step counting from now on. Exists so the walk screen can be tested with a fake.
public protocol StepCounter: AnyObject {
    var isAvailable: Bool { get }
    /// `onUpdate` receives steps since `start`, or `nil` when motion access is denied. Called on any queue.
    func start(onUpdate: @escaping @Sendable (Int?) -> Void)
    func stop()
}

public final class PedometerStepCounter: StepCounter {
    private let pedometer = CMPedometer()

    public init() {}

    public var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    public func start(onUpdate: @escaping @Sendable (Int?) -> Void) {
        pedometer.startUpdates(from: Date()) { data, error in
            if let data {
                onUpdate(data.numberOfSteps.intValue)
            } else if error != nil {
                onUpdate(nil)
            }
        }
    }

    public func stop() {
        pedometer.stopUpdates()
    }
}
#endif
