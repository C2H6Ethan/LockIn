import Foundation

struct StreakData: Codable, Equatable {
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: String?  // dateString of last fully-completed day

    init(currentStreak: Int = 0, longestStreak: Int = 0, lastCompletedDate: String? = nil) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCompletedDate = lastCompletedDate
    }
}
