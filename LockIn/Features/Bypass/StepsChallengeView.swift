import SwiftUI

struct StepsChallengeView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: StepsChallengeViewModel

    init() {
        _viewModel = State(initialValue: StepsChallengeViewModel())
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            if viewModel.isComplete {
                completionView
            } else {
                challengeView
            }
        }
        .onAppear {
            viewModel.startTracking()
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.stopTracking()
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Challenge screen

    private var challengeView: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .font(.system(.body))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.md)

            Spacer()

            // Circular progress ring
            ZStack {
                // Background track
                Circle()
                    .stroke(DesignSystem.Colors.accent.opacity(0.15), lineWidth: 8)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        DesignSystem.Colors.accent,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)

                // Step count inside ring
                VStack(spacing: 4) {
                    Text("\(viewModel.stepCount)")
                        .font(.system(.title, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.primaryText)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: viewModel.stepCount)

                    Text("of \(viewModel.goal) steps")
                        .font(.system(.caption))
                        .foregroundStyle(DesignSystem.Colors.secondaryText)
                }
            }
            .frame(width: 220, height: 220)

            Spacer().frame(height: DesignSystem.Spacing.xl)

            // Status text
            Text(statusText)
                .font(.system(.body))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
                .animation(.easeInOut(duration: 0.3), value: statusText)

            // Motion permission error
            if viewModel.motionDenied {
                Text("Motion access required. Enable in Settings → Privacy & Security → Motion & Fitness → LockIn.")
                    .font(.system(.caption))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
            }

            Spacer()
        }
    }

    // MARK: - Completion screen

    private var completionView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()
            DesignSystem.Typography.title("You gave in.")
            DesignSystem.Typography.secondary("Blocked again at \(expiryTimeString).")
                .multilineTextAlignment(.center)
            Spacer()
            Button("Got it") { dismiss() }
                .font(.system(.body, weight: .regular))
                .foregroundStyle(DesignSystem.Colors.accent)
                .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private var expiryTimeString: String {
        let expiry = Date().addingTimeInterval(TimeInterval(Constants.Stepping.accessWindowMinutes * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: expiry)
    }

    // MARK: - Helpers

    private var progress: Double {
        guard viewModel.goal > 0 else { return 0 }
        return min(Double(viewModel.stepCount) / Double(viewModel.goal), 1.0)
    }

    private var statusText: String {
        switch progress {
        case 0..<0.25: return "Get moving."
        case 0.25..<0.75: return "Keep going."
        case 0.75..<1.0: return "Almost there."
        default: return "Done."
        }
    }
}
