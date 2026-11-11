import Foundation

/// A short window, earned by walking, during which the Shield is lifted (see GLOSSARY: Bypass).
public struct Bypass: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    public let start: Date
    public var end: Date

    public func isActive(at now: Date) -> Bool { start <= now && now < end }
}

/// The Bypasses of the current and previous Day: enough to price the next one and to know if one is active.
public struct BypassLog: Hashable, Codable, Sendable {
    public static let window: TimeInterval = 15 * 60
    static let stepsPerLevel = 100
    static let maxSteps = 1000
    /// A bypass-end callback this close before the end still ends the window (DeviceActivity works in minutes).
    static let earlyCallbackTolerance: TimeInterval = 60

    public private(set) var bypasses: [Bypass] = []

    public init() {}

    /// 100 steps for the first Bypass of a Day, 100 more for each after it, capped at 1,000.
    public static func stepCost(usedToday: Int) -> Int {
        min(stepsPerLevel * (usedToday + 1), maxSteps)
    }

    public func usedCount(on day: DayKey, calendar: Calendar) -> Int {
        bypasses.filter { DayKey($0.start, calendar: calendar) == day }.count
    }

    public func nextStepCost(on day: DayKey, calendar: Calendar) -> Int {
        Self.stepCost(usedToday: usedCount(on: day, calendar: calendar))
    }

    public func active(at now: Date) -> Bypass? {
        bypasses.last.flatMap { $0.isActive(at: now) ? $0 : nil }
    }

    /// The latest Bypass, if its window hasn't ended yet.
    public func pending(at now: Date) -> Bypass? {
        bypasses.last.flatMap { $0.end > now ? $0 : nil }
    }

    /// Starts a window now. A still-active window ends where the new one begins, so there's only ever one.
    @discardableResult
    public mutating func start(at now: Date, id: UUID = UUID(), calendar: Calendar) -> Bypass {
        let today = DayKey(now, calendar: calendar)
        let yesterday = today.adding(days: -1, in: calendar)
        bypasses.removeAll { DayKey($0.start, calendar: calendar) < yesterday }
        if let last = bypasses.indices.last, bypasses[last].end > now { bypasses[last].end = now }
        let bypass = Bypass(id: id, start: now, end: now.addingTimeInterval(Self.window))
        bypasses.append(bypass)
        return bypass
    }

    /// Handles a bypass-end callback. Acts only if `end` is the current window's end; a stale callback for an
    /// older window returns `nil` and changes nothing. Returns the Bypass that just ended.
    public mutating func expire(endingAt end: Date, now: Date) -> Bypass? {
        guard let last = bypasses.indices.last,
              abs(bypasses[last].end.timeIntervalSince(end)) < 1,
              now >= end.addingTimeInterval(-Self.earlyCallbackTolerance)
        else { return nil }
        bypasses[last].end = min(bypasses[last].end, now)
        return bypasses[last]
    }
}

extension Document where Value == BypassLog {
    public static let bypasses = Document("bypasses") { BypassLog() }
}
