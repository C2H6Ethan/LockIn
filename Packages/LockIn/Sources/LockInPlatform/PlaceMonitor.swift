#if os(iOS)
import CoreLocation
import Foundation
import LockInCore

/// Background region monitoring for Location Tasks, with iOS 17's `CLMonitor`. One circular condition per
/// Location Task, identified by the Task id. When a region event relaunches LockIn in the background,
/// `start` (called from `didFinishLaunching`) reopens the same monitor and receives the event.
public final class PlaceMonitor: Sendable {
    private let core: Core
    private nonisolated(unsafe) let manager = CLLocationManager()

    /// `onVisit` is called on entering a Location Task's place, on a background task.
    public init(onVisit: @escaping @Sendable (LockInTask.ID) -> Void) {
        core = Core(onVisit: onVisit)
    }

    /// Asks for "Always" access (needed for background visits). iOS shows the prompt once. Call on the main thread.
    public func requestAuthorization() {
        if manager.authorizationStatus == .notDetermined || manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestAlwaysAuthorization()
        }
    }

    /// Makes the monitored regions match the Location Tasks, and starts listening for events. Idempotent.
    public func sync(tasks: [LockInTask]) {
        let places = Dictionary(tasks.compactMap { t in t.place.map { (t.id.uuidString, $0) } }.prefix(LocationRule.maxPlaces),
                                uniquingKeysWith: { first, _ in first })
        Task { await core.sync(places) }
    }

    /// Serializes access to the one `CLMonitor` and its single event stream.
    private actor Core {
        static let monitorName = "lockin.places"

        private let onVisit: @Sendable (LockInTask.ID) -> Void
        private var monitor: CLMonitor?
        private var listener: Task<Void, Never>?

        init(onVisit: @escaping @Sendable (LockInTask.ID) -> Void) {
            self.onVisit = onVisit
        }

        func sync(_ places: [String: Place]) async {
            // Nothing to monitor and never opened: don't create a monitor (or touch location) at all.
            guard !places.isEmpty || monitor != nil else { return }
            let monitor = await open()
            let existing = Set(await monitor.identifiers)
            for id in existing.subtracting(places.keys) { await monitor.remove(id) }
            for (id, place) in places {
                // Re-adding an unchanged place would reset its state; replace only new or moved ones.
                if existing.contains(id), let record = await monitor.record(for: id),
                   let condition = record.condition as? CLMonitor.CircularGeographicCondition,
                   condition.center.latitude == place.latitude, condition.center.longitude == place.longitude {
                    continue
                }
                let condition = CLMonitor.CircularGeographicCondition(
                    center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                    radius: Place.radius
                )
                await monitor.add(condition, identifier: id, assuming: .unsatisfied)
            }
        }

        private func open() async -> CLMonitor {
            if let monitor { return monitor }
            let opened = await CLMonitor(Self.monitorName)
            if let monitor { return monitor }  // another caller won the race while we awaited
            monitor = opened
            let onVisit = onVisit
            listener = Task {
                do {
                    for try await event in await opened.events where event.state == .satisfied {
                        if let id = UUID(uuidString: event.identifier) { onVisit(id) }
                    }
                } catch {}
            }
            return opened
        }
    }
}

/// A single fresh location fix, for completing a Location Task on the spot.
public enum CurrentLocation {
    public static func fix(timeout: Duration = .seconds(15)) async -> Coordinate? {
        await withTaskGroup(of: Coordinate?.self) { group in
            group.addTask {
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if let location = update.location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100 {
                            return Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                        }
                    }
                } catch {}
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
#endif
