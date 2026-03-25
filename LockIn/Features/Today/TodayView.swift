import SwiftUI

/// Capsule outline that starts tracing from top-center (clockwise).
private struct TopStartCapsule: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.height / 2
        var p = Path()
        // Start at top center, go clockwise
        p.move(to: CGPoint(x: rect.midX, y: 0))
        // Top-right straight + right arc
        p.addLine(to: CGPoint(x: rect.maxX - r, y: 0))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: r),
                  radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        // Bottom-right to bottom-left
        p.addLine(to: CGPoint(x: r, y: rect.maxY))
        // Left arc
        p.addArc(center: CGPoint(x: r, y: r),
                  radius: r, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        // Top-left back to top center
        p.addLine(to: CGPoint(x: rect.midX, y: 0))
        return p
    }
}

// Animatable conformance is required by KeyframeAnimator.
private struct StreakAnimValues: Animatable {
    var scale: Double = 1.0
    var brightness: Double = 0.0
    var yOffset: Double = 0.0

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(scale, AnimatablePair(brightness, yOffset)) }
        set {
            scale = newValue.first
            brightness = newValue.second.first
            yOffset = newValue.second.second
        }
    }
}

struct TodayView: View {

    @State private var viewModel = TodayViewModel()
    @Environment(\.scenePhase) private var scenePhase
    // Local trigger so KeyframeAnimator sees a change after the view exists.
    @State private var burstTrigger = 0
    @State private var undoProgress: CGFloat = 1.0

    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()

            if viewModel.todayTasks.isEmpty && viewModel.completedTasks.isEmpty {
                if viewModel.hasCompletedTaskToday {
                    allDoneFullState
                } else {
                    emptyState
                }
            } else {
                taskList
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.showUndoToast)
        .onChange(of: viewModel.undoTaskID) { _, newID in
            if newID != nil {
                undoProgress = 1.0
                withAnimation(.linear(duration: 4.0)) {
                    undoProgress = 0.0
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                undoProgress = 1.0
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            streakBanner
        }
        .onAppear { viewModel.onAppear() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { viewModel.onAppear() }
        }
        // Streak incremented while the list is still visible (non-final task completion):
        // fire haptic + burst immediately since the banner is already on screen.
        .onChange(of: viewModel.streakAnimationTrigger) {
            burstTrigger += 1
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
        .sheet(isPresented: $viewModel.showingAddTask) {
            AddTaskSheet(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: Binding(
            get: { viewModel.pendingFreezeOffer },
            set: { _ in }
        )) {
            StreakFreezeSheet(
                onUse: { viewModel.consumeFreeze() },
                onDecline: { viewModel.declineFreeze() }
            )
        }
    }

    // MARK: - Subviews

    private var streakBanner: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text("Today's Tasks")
                .font(.system(.largeTitle, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.primaryText)

            if viewModel.streak > 0 {
                KeyframeAnimator(
                    initialValue: StreakAnimValues(),
                    trigger: burstTrigger
                ) { value in
                    Text("\(viewModel.streak) \(viewModel.streak == 1 ? "day" : "days") locked in")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .scaleEffect(value.scale, anchor: .leading)
                        .brightness(value.brightness)
                        .offset(y: value.yOffset)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(1.0, duration: 0.01)
                        SpringKeyframe(1.22, duration: 0.14, spring: .init(duration: 0.14, bounce: 0.6))
                        SpringKeyframe(0.96, duration: 0.10, spring: .smooth)
                        SpringKeyframe(1.0,  duration: 0.18, spring: .smooth)
                    }
                    KeyframeTrack(\.brightness) {
                        LinearKeyframe(0.0,  duration: 0.01)
                        LinearKeyframe(0.55, duration: 0.10)
                        LinearKeyframe(0.0,  duration: 0.28)
                    }
                    KeyframeTrack(\.yOffset) {
                        LinearKeyframe(0.0, duration: 0.01)
                        SpringKeyframe(-4,  duration: 0.12, spring: .bouncy)
                        SpringKeyframe(0,   duration: 0.20, spring: .smooth)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.xs)
        .background(DesignSystem.Colors.background)
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if viewModel.allBlockingDone {
                    allDoneRow
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                ForEach(viewModel.todayTasks) { task in
                    TaskRowView(
                        task: task,
                        onComplete: {
                            withAnimation(.easeOut(duration: 0.25)) {
                                viewModel.completeTask(task)
                            }
                        },
                        stepCount: task.stepTarget != nil ? viewModel.stepsToday : nil
                    )
                    .id("incomplete-\(task.id)")
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .transition(.opacity)
                }

                ForEach(viewModel.completedTasks) { task in
                    HStack {
                        TaskRowView(
                            task: task,
                            onComplete: {},
                            stepCount: task.stepTarget != nil ? viewModel.stepsToday : nil,
                            isCompleted: true
                        )

                        if viewModel.showUndoToast && viewModel.undoTaskID == task.id {
                            undoPill
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .id("completed-\(task.id)")
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .transition(.opacity)
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.todayTasks.map { $0.id })
        .animation(.easeOut(duration: 0.25), value: viewModel.completedTasks.map { $0.id })
    }

    // Shown inline when all blocking tasks done. Message changes when everything is done.
    private var allDoneRow: some View {
        Text(viewModel.todayTasks.isEmpty ? "All done for today." : "Blocking tasks done — apps unlocked.")
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(DesignSystem.Colors.accent)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
    }

    // Shown when every task for the day is gone.
    // onAppear fires the burst after the transition completes so
    // KeyframeAnimator sees a trigger change while the view is live.
    private var allDoneFullState: some View {
        Text("All done for today.")
            .font(.system(.title3, weight: .medium))
            .foregroundStyle(DesignSystem.Colors.primaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var undoPill: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.easeOut(duration: 0.25)) {
                viewModel.undoLastCompletion()
            }
        } label: {
            Text("Undo")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    TopStartCapsule()
                        .trim(from: 0, to: undoProgress)
                        .stroke(DesignSystem.Colors.accent.opacity(0.4), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        Text("No tasks today. Enjoy your day.")
            .font(.system(.body))
            .foregroundStyle(DesignSystem.Colors.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
            .padding(DesignSystem.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
}
