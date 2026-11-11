import Foundation

/// A point on Earth. Framework-free stand-in for `CLLocationCoordinate2D`.
public struct Coordinate: Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in meters (haversine).
    public func distance(to other: Coordinate) -> Double {
        let r = 6_371_000.0
        let φ1 = latitude * .pi / 180, φ2 = other.latitude * .pi / 180
        let dφ = (other.latitude - latitude) * .pi / 180
        let dλ = (other.longitude - longitude) * .pi / 180
        let a = sin(dφ / 2) * sin(dφ / 2) + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }
}

/// Where a Location Task must be visited.
public struct Place: Hashable, Codable, Sendable {
    public static let radius: Double = 200

    public let name: String
    public let latitude: Double
    public let longitude: Double

    public init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    public var coordinate: Coordinate { Coordinate(latitude: latitude, longitude: longitude) }

    public func contains(_ point: Coordinate) -> Bool {
        coordinate.distance(to: point) <= Self.radius
    }
}

/// Which Location Tasks' places were visited on which Day, recorded by background region monitoring.
public struct VisitLog: Hashable, Codable, Sendable {
    static let keptDays = 7
    public private(set) var days: [DayKey: Set<LockInTask.ID>] = [:]

    public init() {}

    public func hasVisited(_ id: LockInTask.ID, on day: DayKey) -> Bool {
        days[day]?.contains(id) ?? false
    }

    /// Records a visit and forgets Days more than a week before `day`.
    public mutating func record(_ id: LockInTask.ID, on day: DayKey, calendar: Calendar) {
        days[day, default: []].insert(id)
        let oldest = day.adding(days: -(Self.keptDays - 1), in: calendar)
        days = days.filter { $0.key >= oldest }
    }
}

extension Document where Value == VisitLog {
    public static let visits = Document("visits") { VisitLog() }
}

/// Location Tasks (see GLOSSARY).
public enum LocationRule {
    /// iOS monitors at most 20 regions per app.
    public static let maxPlaces = 20

    /// A Location Task may be completed once its place was visited today, or the current fix is within its radius.
    /// Other kinds are not gated.
    public static func canComplete(task: LockInTask, visits: VisitLog, currentLocation: Coordinate?, day: DayKey) -> Bool {
        guard let place = task.place else { return true }
        if visits.hasVisited(task.id, on: day) { return true }
        return currentLocation.map(place.contains) ?? false
    }
}
