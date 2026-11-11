import SwiftUI

@main
struct LockInApp: App {
    var body: some Scene {
        WindowGroup {
            PlaceholderView()
        }
    }
}

private struct PlaceholderView: View {
    var body: some View {
        Text("LockIn")
            .font(.system(.title2, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.background)
    }
}
