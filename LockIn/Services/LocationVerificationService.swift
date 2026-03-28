import CoreLocation

// MARK: - Protocol (enables test injection)

protocol LocationVerifying: AnyObject {
    func verifyCurrentLocation(for task: TodayTask) async -> Bool
    func registerGeofences(for tasks: [TodayTask]) async
    func startMonitoringEvents() async
    func requestAuthorization()
    func requestAlwaysAuthorization()
    var authorizationStatus: CLAuthorizationStatus { get }
}

// MARK: - Live service

final class LocationVerificationService: NSObject, LocationVerifying {

    static let shared = LocationVerificationService()

    private let locationManager: CLLocationManager
    private var _monitor: CLMonitor?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var monitoringTask: _Concurrency.Task<Void, Never>?

    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    private override init() {
        self.locationManager = CLLocationManager()
        super.init()
        self.locationManager.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Geofencing (CLMonitor)

    /// Register geofences for all location tasks. Call on every app launch (re-registers
    /// conditions that may have been cleared by a device reboot).
    func registerGeofences(for tasks: [TodayTask]) async {
        let mon = await getMonitor()
        let locationTasks = tasks.filter { $0.location != nil }
        for task in locationTasks {
            let loc = task.location!
            let identifier = task.id.uuidString
            let center = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)

            // CLMonitor — foreground/active background delivery
            let condition = CLMonitor.CircularGeographicCondition(center: center, radius: loc.radius)
            await mon.add(condition, identifier: identifier)

            // CLCircularRegion — wakes app from terminated state (no persistent indicator)
            guard !locationManager.monitoredRegions.contains(where: { $0.identifier == identifier }) else { continue }
            let region = CLCircularRegion(center: center, radius: loc.radius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationManager.startMonitoring(for: region)
        }

        // Check if already inside any location task's region — iOS won't fire
        // an entry event for regions you're already in when monitoring starts.
        // Log the visit silently (no notification since the user is in-app).
        if !locationTasks.isEmpty,
           let current = await requestCurrentLocation() {
            let today = Date().dateString
            for task in locationTasks {
                let loc = task.location!
                let target = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                if current.distance(from: target) <= loc.radius {
                    await MainActor.run {
                        SharedStore.shared.logLocationVisit(taskID: task.id, on: today)
                    }
                }
            }
        }
    }

    func removeGeofence(for taskID: UUID) async {
        let identifier = taskID.uuidString
        let mon = await getMonitor()
        await mon.remove(identifier)
        if let region = locationManager.monitoredRegions.first(where: { $0.identifier == identifier }) {
            locationManager.stopMonitoring(for: region)
        }
    }

    /// Start the CLMonitor event loop exactly once. Subsequent calls are no-ops.
    /// Safe to call on every app launch — guards against duplicate loops from scene re-activation.
    func startMonitoringEventsOnce() {
        guard monitoringTask == nil else { return }
        monitoringTask = _Concurrency.Task.detached { [weak self] in
            await self?.startMonitoringEvents()
        }
    }

    /// Long-running async loop — iterates CLMonitor events and logs visits to SharedStore.
    /// Do not call directly; use `startMonitoringEventsOnce()` instead.
    func startMonitoringEvents() async {
        let mon = await getMonitor()
        do {
            for try await event in mon.events {
                guard case .satisfied = event.state else { continue }
                guard let taskID = UUID(uuidString: event.identifier) else { continue }
                let today = Date().dateString
                // Log visit only — didEnterRegion handles notifications reliably
                // in foreground, background, and terminated states.
                await MainActor.run {
                    SharedStore.shared.logLocationVisit(taskID: taskID, on: today)
                }
            }
        } catch {
            // Monitoring ended or device rebooted — will re-register on next app launch
        }
    }

    // MARK: - Proximity check (foreground fallback)

    /// Returns true if user is currently within range of the task's saved location.
    /// Returns false if location permission is denied.
    func verifyCurrentLocation(for task: TodayTask) async -> Bool {
        guard let location = task.location else { return true }
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return false }
        guard let current = await requestCurrentLocation() else { return false }
        let target = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return current.distance(from: target) <= location.radius
    }

    private func requestCurrentLocation() async -> CLLocation? {
        // Resume any in-flight continuation before starting a new request.
        // Prevents leaks when the method is called concurrently (e.g. rapid taps).
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()

            // Hard timeout — resume with nil if the delegate never fires
            // (e.g. GPS unavailable, authorization revoked mid-flight).
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self, let pending = self.locationContinuation else { return }
                self.locationContinuation = nil
                pending.resume(returning: nil)
            }
        }
    }

    // MARK: - Monitor lazy init

    private func getMonitor() async -> CLMonitor {
        if let m = _monitor { return m }
        let m = await CLMonitor("lockinGeofences")
        _monitor = m
        return m
    }

}

// MARK: - CLLocationManagerDelegate

extension LocationVerificationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationContinuation?.resume(returning: locations.first)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let taskID = UUID(uuidString: region.identifier) else { return }
        let store = SharedStore(suiteName: Constants.AppGroup.id)
        store.logLocationVisit(taskID: taskID, on: Date().dateString)
    }
}
