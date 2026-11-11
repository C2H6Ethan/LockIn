import SwiftUI

/// Every visual constant in the app. No cards, no borders: typography and whitespace only.
enum DesignSystem {
    enum Colors {
        static let background = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
        static let primaryText = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF0 / 255)
        static let secondaryText = Color(red: 0x6B / 255, green: 0x6B / 255, blue: 0x6B / 255)
        static let accent = Color(red: 0xE8 / 255, green: 0xD5 / 255, blue: 0xA3 / 255)
        static let destructive = Color(red: 0xFF / 255, green: 0x44 / 255, blue: 0x44 / 255)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 40
        /// Width of the leading marker column in Task rows.
        static let rowMarker: CGFloat = 22
    }

    enum CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 12
    }
}
