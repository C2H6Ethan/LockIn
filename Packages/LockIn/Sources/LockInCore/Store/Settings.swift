import Foundation

/// User preferences that aren't Tasks or the Blocklist.
public struct Settings: Hashable, Codable, Sendable {
    public static let defaultReminderTime = TimeOfDay(hour: 20, minute: 0)!

    /// `nil` means the reminder is off.
    public var reminderTime: TimeOfDay?
    public var hasCompletedOnboarding: Bool
    /// The Day onboarding finished. Day records (008) start here.
    public var firstDay: DayKey?
    /// A Streak imported from v2 (014).
    public var streakSeed: StreakSeed?
    /// The newest Missed Day the user has seen in the Missed-Day Recap.
    public var recapAcknowledgedThrough: DayKey?

    public init(reminderTime: TimeOfDay? = Settings.defaultReminderTime, hasCompletedOnboarding: Bool = false, firstDay: DayKey? = nil, streakSeed: StreakSeed? = nil) {
        self.reminderTime = reminderTime
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.firstDay = firstDay
        self.streakSeed = streakSeed
    }

    private enum CodingKeys: String, CodingKey {
        case reminderTime, hasCompletedOnboarding, firstDay, streakSeed, recapAcknowledgedThrough
    }

    /// Missing fields fall back to defaults so older documents keep decoding.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reminderTime = c.contains(.reminderTime) ? try c.decode(TimeOfDay?.self, forKey: .reminderTime) : Settings.defaultReminderTime
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        firstDay = try c.decodeIfPresent(DayKey.self, forKey: .firstDay)
        streakSeed = try c.decodeIfPresent(StreakSeed.self, forKey: .streakSeed)
        recapAcknowledgedThrough = try c.decodeIfPresent(DayKey.self, forKey: .recapAcknowledgedThrough)
    }

    /// `reminderTime` is always written, including as `null`, so "off" survives a round trip
    /// instead of decoding as missing and falling back to the default.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(reminderTime, forKey: .reminderTime)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try c.encodeIfPresent(firstDay, forKey: .firstDay)
        try c.encodeIfPresent(streakSeed, forKey: .streakSeed)
        try c.encodeIfPresent(recapAcknowledgedThrough, forKey: .recapAcknowledgedThrough)
    }
}
