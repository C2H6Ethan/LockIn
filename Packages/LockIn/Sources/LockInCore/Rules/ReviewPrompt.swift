/// When to ask for an App Store review: once, the first time the Streak reaches a week.
public enum ReviewPrompt {
    public static let streakThreshold = 7

    public static func shouldRequest(streak: Int, alreadyRequested: Bool) -> Bool {
        !alreadyRequested && streak >= streakThreshold
    }
}
