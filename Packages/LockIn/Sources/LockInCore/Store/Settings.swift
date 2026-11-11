import Foundation

/// User preferences that aren't Tasks or the Blocklist.
public struct Settings: Hashable, Codable, Sendable {
    public static let defaultReminderTime = TimeOfDay(hour: 20, minute: 0)!

    /// `nil` means the reminder is off.
    public var reminderTime: TimeOfDay?
    public var hasCompletedOnboarding: Bool
    /// The Day onboarding finished. Day records (008) start here.
    public var firstDay: DayKey?

    public init(reminderTime: TimeOfDay? = Settings.defaultReminderTime, hasCompletedOnboarding: Bool = false, firstDay: DayKey? = nil) {
        self.reminderTime = reminderTime
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.firstDay = firstDay
    }

    /// Missing fields fall back to defaults so older documents keep decoding.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reminderTime = c.contains(.reminderTime) ? try c.decode(TimeOfDay?.self, forKey: .reminderTime) : Settings.defaultReminderTime
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        firstDay = try c.decodeIfPresent(DayKey.self, forKey: .firstDay)
    }
}
