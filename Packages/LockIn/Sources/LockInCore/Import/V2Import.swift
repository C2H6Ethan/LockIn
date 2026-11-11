import Foundation

/// Raw v2 values read from the App Group under v2's unprefixed keys (see v2 SharedStore on main).
public struct V2Snapshot: Sendable {
    public var tasks: Data?
    public var completionLog: Data?
    public var streakData: Data?
    public var selectedWebDomains: [String]?
    public var reminderNever: Bool
    public var reminderHour: Int?
    public var reminderMinute: Int?
    public var hasCompletedOnboarding: Bool

    public init(tasks: Data?, completionLog: Data?, streakData: Data?, selectedWebDomains: [String]?,
                reminderNever: Bool, reminderHour: Int?, reminderMinute: Int?, hasCompletedOnboarding: Bool) {
        self.tasks = tasks
        self.completionLog = completionLog
        self.streakData = streakData
        self.selectedWebDomains = selectedWebDomains
        self.reminderNever = reminderNever
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    /// Whether a v2 install left data behind.
    public var isPresent: Bool { tasks != nil || hasCompletedOnboarding }
}

/// v2 data that later tickets (016 Step-Goal, 017 Location) turn into Task kinds.
public struct V2Leftovers: Hashable, Codable, Sendable {
    public struct Place: Hashable, Codable, Sendable {
        public let name: String
        public let latitude: Double
        public let longitude: Double
    }

    public var stepTargets: [LockInTask.ID: Int] = [:]
    public var locations: [LockInTask.ID: Place] = [:]

    public init() {}
}

extension Document where Value == V2Leftovers {
    public static let v2Leftovers = Document("v2Leftovers") { V2Leftovers() }
}

public struct V2ImportResult: Sendable {
    public let tasks: [LockInTask]
    public let completions: CompletionLog
    public let settings: Settings
    public let customDomains: [String]
    public let leftovers: V2Leftovers
}

/// Maps v2 data to v3. Pure; the platform reads the snapshot and writes the result.
public enum V2Import {
    public static func map(_ snapshot: V2Snapshot, today: DayKey, calendar: Calendar) throws -> V2ImportResult {
        let decoder = JSONDecoder()
        let v2Tasks = try snapshot.tasks.map { try decoder.decode([V2Task].self, from: $0) } ?? []
        let v2Log = (try? snapshot.completionLog.map { try decoder.decode([String: Set<UUID>].self, from: $0) }) ?? [:]
        let v2Streak = try? snapshot.streakData.map { try decoder.decode(V2StreakData.self, from: $0) }

        var tasks: [LockInTask] = []
        var leftovers = V2Leftovers()
        for old in v2Tasks {
            guard let schedule = schedule(for: old, log: v2Log, today: today) else { continue }
            let start = old.blockingStartTime.map { TimeOfDay.nearestAllowed(hour: $0.hour ?? 0, minute: $0.minute ?? 0) }
            tasks.append(LockInTask(id: old.id, title: old.title, schedule: schedule,
                                    requirement: old.blocksApps ? .required : .optional, startTime: start, createdOn: today))
            if let target = old.stepTarget { leftovers.stepTargets[old.id] = target }
            if let place = old.location {
                leftovers.locations[old.id] = .init(name: place.name, latitude: place.latitude, longitude: place.longitude)
            }
        }

        let importedIDs = Set(tasks.map(\.id))
        var completions = CompletionLog()
        for id in v2Log[today.description] ?? [] where importedIDs.contains(id) {
            completions.set(id, completed: true, on: today)
        }

        var settings = Settings()
        settings.hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        settings.firstDay = today
        settings.reminderTime = snapshot.reminderNever
            ? nil
            : TimeOfDay.nearestAllowed(hour: snapshot.reminderHour ?? Settings.defaultReminderTime.hour, minute: snapshot.reminderMinute ?? 0)
        settings.streakSeed = v2Streak.flatMap { seed(from: $0, today: today, calendar: calendar) }

        var domains: [String] = []
        for raw in snapshot.selectedWebDomains ?? [] { _ = CustomDomain.add(raw, to: &domains) }

        return V2ImportResult(tasks: tasks, completions: completions, settings: settings, customDomains: domains, leftovers: leftovers)
    }

    private static func schedule(for task: V2Task, log: [String: Set<UUID>], today: DayKey) -> Schedule? {
        switch task.recurrence {
        case .weekly(let days):
            let weekdays = Set(days.compactMap(Weekday.init(rawValue:)))
            return weekdays.isEmpty ? nil : .weekly(weekdays)
        case .once(let startDate):
            // v2 showed a one-time Task from its start date until completed.
            let start = DayKey(startDate) ?? today
            let done = log.contains { key, ids in (DayKey(key).map { $0 >= start } ?? false) && ids.contains(task.id) }
            return done ? nil : .once(max(start, today))
        }
    }

    /// v2's Streak counted through `lastCompletedDate`. It continues only if that was yesterday or today.
    private static func seed(from data: V2StreakData, today: DayKey, calendar: Calendar) -> StreakSeed? {
        guard data.currentStreak > 0, let last = data.lastCompletedDate.flatMap(DayKey.init) else { return nil }
        let yesterday = today.adding(days: -1, in: calendar)
        if last == yesterday { return StreakSeed(count: data.currentStreak, asOf: yesterday) }
        // Today was already counted by v2; today's imported completions make it Kept again in v3.
        if last == today, data.currentStreak > 1 { return StreakSeed(count: data.currentStreak - 1, asOf: yesterday) }
        return nil
    }
}

// MARK: - v2 shapes (decoding only)

private struct V2Task: Decodable {
    enum Recurrence: Decodable {
        case weekly(days: Set<Int>)
        case once(startDate: String)
    }

    struct Location: Decodable {
        let latitude: Double
        let longitude: Double
        let name: String
    }

    let id: UUID
    let title: String
    let recurrence: Recurrence
    let blocksApps: Bool
    let stepTarget: Int?
    let blockingStartTime: DateComponents?
    let location: Location?
}

private struct V2StreakData: Decodable {
    let currentStreak: Int
    let lastCompletedDate: String?
}
