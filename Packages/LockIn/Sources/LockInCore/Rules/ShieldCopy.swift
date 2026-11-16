import Foundation

/// Words on the system Shield. Kept in the core so the shield extension holds no copy of its own.
public enum ShieldCopy {
    public static let primaryButton = "Lock In"
    public static let secondaryButton = "Earn a Bypass"

    public static let shameMessages = [
        "Not yet.",
        "Tasks first.",
        "This will still be here later.",
        "You know what's left.",
        "Still blocked.",
        "It's not going anywhere.",
        "Probably nothing urgent.",
        "Your tasks are waiting.",
        "Later.",
        "Back to it.",
    ]

    public static let headers = [
        "Still to do",
        "Finish these first",
        "Left today",
        "Blocked until these are done",
        "Do these, then come back",
    ]

    static let maxListed = 3

    public static func title<G: RandomNumberGenerator>(using rng: inout G) -> String {
        shameMessages.randomElement(using: &rng)!
    }

    /// A header and up to three owed Tasks, or `nil` when nothing is owed.
    public static func subtitle<G: RandomNumberGenerator>(owed titles: [String], using rng: inout G) -> String? {
        guard !titles.isEmpty else { return nil }
        var lines = [headers.randomElement(using: &rng)!]
        lines += titles.prefix(maxListed).map { "• \($0)" }
        if titles.count > maxListed { lines.append("+\(titles.count - maxListed) more") }
        return lines.joined(separator: "\n")
    }
}

/// LockIn's colors as plain values, shared by the app and the extensions.
public enum Palette {
    public struct RGB: Sendable {
        public let red: Double, green: Double, blue: Double
        init(_ hex: UInt32) {
            red = Double((hex >> 16) & 0xFF) / 255
            green = Double((hex >> 8) & 0xFF) / 255
            blue = Double(hex & 0xFF) / 255
        }
    }

    public static let background = RGB(0x0A0A0A)
    public static let primaryText = RGB(0xF5F5F0)
    public static let secondaryText = RGB(0x8A8A8A)
    public static let accent = RGB(0xE8D5A3)
    public static let destructive = RGB(0xFF4444)
}

/// Links into the app, from notifications and the Shield.
public enum DeepLink: String, Sendable {
    case today, bypass

    public init?(url: URL) {
        guard url.scheme == "lockin", let host = url.host(), let link = DeepLink(rawValue: host) else { return nil }
        self = link
    }

    public var url: URL { URL(string: "lockin://\(rawValue)")! }
}
