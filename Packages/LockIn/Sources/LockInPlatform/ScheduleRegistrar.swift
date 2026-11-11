#if os(iOS)
import DeviceActivity
import Foundation
import LockInCore

/// The DeviceActivityCenter calls LockIn needs. Exists so registration can be tested with a fake.
public protocol ActivityCenter {
    var activityNames: [String] { get }
    func startMonitoring(_ name: String, during schedule: DeviceActivitySchedule) throws
    func stopMonitoring(_ names: [String])
}

extension DeviceActivityCenter: ActivityCenter {
    public var activityNames: [String] { activities.map(\.rawValue) }

    public func startMonitoring(_ name: String, during schedule: DeviceActivitySchedule) throws {
        try startMonitoring(DeviceActivityName(name), during: schedule)
    }

    public func stopMonitoring(_ names: [String]) {
        stopMonitoring(names.map { DeviceActivityName($0) })
    }
}

/// Makes the registered activities match the desired ones (ADR 0001).
/// Idempotent, and it always asks the OS what is registered instead of trusting a saved flag.
public struct ScheduleRegistrar {
    public struct Report: Equatable {
        public struct Failure: Equatable {
            public let name: String
            public let reason: String
        }

        public var started: [String] = []
        public var stopped: [String] = []
        public var failures: [Failure] = []

        public var isEmpty: Bool { started.isEmpty && stopped.isEmpty && failures.isEmpty }

        /// One line for the event log, or nil when nothing changed.
        public var summary: String? {
            guard !isEmpty else { return nil }
            var parts: [String] = []
            if !started.isEmpty { parts.append("started \(started.joined(separator: ", "))") }
            if !stopped.isEmpty { parts.append("stopped \(stopped.joined(separator: ", "))") }
            for f in failures { parts.append("FAILED \(f.name): \(f.reason)") }
            return "Schedules: " + parts.joined(separator: "; ")
        }
    }

    private let center: ActivityCenter

    public init(center: ActivityCenter = DeviceActivityCenter()) {
        self.center = center
    }

    @discardableResult
    public func sync(desired: Set<ScheduledActivity>, calendar: Calendar = .current) -> Report {
        var report = Report()
        let registered = Set(center.activityNames)
        let desiredByName = Dictionary(uniqueKeysWithValues: desired.map { ($0.name, $0) })

        // Anything not desired goes, including activities left behind by v2.
        let stale = registered.subtracting(desiredByName.keys).sorted()
        if !stale.isEmpty {
            center.stopMonitoring(stale)
            report.stopped = stale
        }

        for name in desiredByName.keys.sorted() where !registered.contains(name) {
            do {
                try center.startMonitoring(name, during: Self.schedule(for: desiredByName[name]!, calendar: calendar))
                report.started.append(name)
            } catch {
                report.failures.append(.init(name: name, reason: String(describing: error)))
            }
        }
        return report
    }

    /// Repeating activities run daily from their start to 23:59; the 23:30 cap on Start Times keeps intervals ≥ 29 minutes.
    /// A `bypassEnd` runs once, starting at the Bypass end (DeviceActivity needs intervals of at least 15 minutes).
    public static func schedule(for activity: ScheduledActivity, calendar: Calendar = .current) -> DeviceActivitySchedule {
        guard let start = activity.intervalStart else {
            guard case .bypassEnd(let end) = activity else { preconditionFailure("only bypassEnd is one-shot") }
            let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            return DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(parts, from: end),
                intervalEnd: calendar.dateComponents(parts, from: end.addingTimeInterval(16 * 60)),
                repeats: false
            )
        }
        return DeviceActivitySchedule(
            intervalStart: DateComponents(hour: start.hour, minute: start.minute),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
    }
}
#endif
