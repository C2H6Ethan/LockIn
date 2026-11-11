import LockInCore
import SwiftUI

/// What the app and extensions recorded, newest first. Hidden; used to verify background behaviour on device.
struct EventLogView: View {
    let store: LockInStore
    @State private var events: [Event] = []

    var body: some View {
        List(events.reversed(), id: \.self) { event in
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(event.message)
                    .font(.footnote.monospaced())
                    .foregroundStyle(DesignSystem.Colors.primaryText)
                Text("\(event.date.formatted(date: .abbreviated, time: .standard)) · \(event.source.rawValue)")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            .listRowBackground(DesignSystem.Colors.background)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Colors.background)
        .navigationTitle("Event log")
        .onAppear { events = store.read(.eventLog).events }
        .refreshable { events = store.read(.eventLog).events }
    }
}
