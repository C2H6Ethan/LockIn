import WidgetKit
import SwiftUI

// MARK: - Provider

struct LockInWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> LockInWidgetEntry {
        LockInWidgetEntry(
            date: .now,
            incompleteCount: 2,
            totalCount: 3,
            streak: 7,
            taskTitles: ["Morning run", "Read 20 mins"],
            allDone: false
        )
        // Preview: 7 days locked in, 2 left
    }

    func getSnapshot(in context: Context, completion: @escaping (LockInWidgetEntry) -> Void) {
        completion(LockInWidgetEntry.build())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockInWidgetEntry>) -> Void) {
        let entry = LockInWidgetEntry.build()
        let midnight = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

// MARK: - Small Widget View

private struct SmallWidgetView: View {
    let entry: LockInWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(entry.streak)")
                    .font(.system(.largeTitle, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.accent)
                Text(entry.streak == 1 ? "day locked in" : "days locked in")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            }
            Spacer()
            Text(entry.allDone ? "All done" : "\(entry.incompleteCount) left")
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(
                    entry.allDone
                        ? DesignSystem.Colors.secondaryText
                        : DesignSystem.Colors.primaryText
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(DesignSystem.Colors.background, for: .widget)
    }
}

// MARK: - Medium Widget View

private struct MediumWidgetView: View {
    let entry: LockInWidgetEntry

    private var overflowCount: Int { max(0, entry.incompleteCount - 2) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.streak)")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                    Text(entry.streak == 1 ? "day locked in" : "days locked in")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                Spacer()
                Text(
                    entry.allDone
                        ? "All done"
                        : "\(entry.totalCount - entry.incompleteCount) of \(entry.totalCount) done"
                )
                .font(.system(.subheadline))
                .foregroundStyle(DesignSystem.Colors.secondaryText)
            }

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DesignSystem.Colors.secondaryText.opacity(0.2))

            if entry.allDone || entry.taskTitles.isEmpty {
                Text("Nothing left today.")
                    .font(.system(.caption))
                    .foregroundStyle(DesignSystem.Colors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(entry.taskTitles, id: \.self) { title in
                        HStack(spacing: 6) {
                            Image(systemName: "square")
                                .font(.caption2)
                                .foregroundStyle(DesignSystem.Colors.secondaryText)
                            Text(title)
                                .font(.system(.caption))
                                .foregroundStyle(DesignSystem.Colors.primaryText)
                                .lineLimit(1)
                        }
                    }
                    if overflowCount > 0 {
                        Text("+\(overflowCount) more")
                            .font(.system(.caption2))
                            .foregroundStyle(DesignSystem.Colors.secondaryText)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(DesignSystem.Colors.background, for: .widget)
    }
}

// MARK: - Entry View

struct LockInWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: LockInWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget

struct LockInWidget: Widget {
    let kind = "LockInWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockInWidgetProvider()) { entry in
            LockInWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "lockin://today"))
        }
        .configurationDisplayName("LockIn")
        .description("Track your daily tasks and streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
