import LockInCore
import SwiftUI

/// Every visual constant in the app. No cards, no borders: typography and whitespace only.
enum DesignSystem {
    enum Colors {
        static let background = Color(Palette.background)
        static let primaryText = Color(Palette.primaryText)
        static let secondaryText = Color(Palette.secondaryText)
        static let accent = Color(Palette.accent)
        static let destructive = Color(Palette.destructive)
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

private extension Color {
    init(_ rgb: Palette.RGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
