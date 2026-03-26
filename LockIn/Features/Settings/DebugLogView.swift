import SwiftUI

struct DebugLogView: View {

    @State private var logText: String = ""
    @State private var showingShareSheet = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText.isEmpty ? "No entries yet." : logText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignSystem.Spacing.md)
                        .id("bottom")
                }
                .onAppear {
                    logText = ActivityLog.shared.readAll()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .navigationTitle("Activity Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Clear") {
                    ActivityLog.shared.clear()
                    logText = ""
                }
                .foregroundStyle(DesignSystem.Colors.destructive)

                ShareLink(item: ActivityLog.shared.shareURL) {
                    Image(systemName: "square.and.arrow.up")
                }
                .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
    }
}
