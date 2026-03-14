import SwiftUI

enum DesignSystem {
    enum Colors {
        static let background    = Color(hex: "0A0A0A")
        static let primaryText   = Color(hex: "F5F5F0")
        static let secondaryText = Color(hex: "6B6B6B")
        static let accent        = Color(hex: "E8D5A3")
        static let destructive   = Color(hex: "FF4444")
        static let overdue       = Color(hex: "CC4444")
    }

    enum Typography {
        static func title(_ text: String) -> some View {
            Text(text)
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.primaryText)
        }

        static func secondary(_ text: String) -> some View {
            Text(text)
                .font(.system(.subheadline, design: .default, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
        }

    }

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 40
    }

    enum CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 12
    }
}

// MARK: - Color hex initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255
        )
    }
}
