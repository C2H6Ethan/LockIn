import Foundation

enum Constants {
    enum AppGroup {
        static let id = "group.com.ethanbaumgartner.lockin"
    }

    enum DeviceActivity {
        static let weeklySchedule = "com.ethanbaumgartner.lockin.weekly"   // legacy, cleaned up on launch
        static let dailySchedule  = "com.ethanbaumgartner.lockin.daily"
    }

    enum ShameMessages {
        static let all: [String] = [
            "Do the work now. Enjoy the reward later.",
            "Every minute here is a minute stolen from something better.",
            "The version of you who finished wins.",
            "Close this. Go build something.",
            "Your future self is watching.",
            "The distraction ends. The work remains.",
            "One less excuse. One more reason to finish.",
            "Nothing on here matters as much as what you're avoiding.",
            "Get it done. Then do whatever you want.",
            "You already know what you should be doing.",
        ]

        static func random() -> String {
            all.randomElement() ?? all[0]
        }

        static func random(avoiding previous: String) -> String {
            let options = all.filter { $0 != previous }
            return options.randomElement() ?? all[0]
        }
    }

    enum Bypass {
        static let defaultWindowDuration: TimeInterval = 60
    }

    enum BlockedHeaders {
        static let all: [String] = [
            "earn it first",
            "not yet. complete these",
            "no excuses. finish these",
            "you haven't earned this",
            "blocked until you finish",
            "do these. then come back",
            "not done. not unlocked",
            "close this. finish these",
            "finish what you started",
            "these come first",
        ]

        static func random() -> String {
            all.randomElement() ?? all[0]
        }
    }

    enum Stepping {
        static let notificationID = "com.lockin.bypass"
        static let deepLink = "lockin://bypass"
        static let stepsPerLevel = 100
        static let maxSteps = 1000
        static let accessWindowMinutes = 5
    }

    enum DailyReminder {
        static let notificationID = "com.lockin.daily-reminder"
        static let defaultHour = 20 // 8pm
    }

    enum ShieldDisplay {
        static let primaryButton = "Lock In"

        /// Formats incomplete blocking tasks under a random tough header.
        static func subtitleText(for tasks: [TodayTask], maxCount: Int = 3) -> String {
            guard !tasks.isEmpty else { return "" }
            let items = tasks.prefix(maxCount).map { "• \($0.title)" }.joined(separator: "\n")
            return "\(BlockedHeaders.random())\n\(items)"
        }
    }
}
