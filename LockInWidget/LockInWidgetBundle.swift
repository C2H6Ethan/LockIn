import LockInCore
import SwiftUI
import WidgetKit

@main
struct LockInWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

/// Today's Required progress and the Streak. Read-only; all numbers come from `WidgetSnapshot`.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: Provider()) { entry in
            TodayWidgetView(snapshot: entry.snapshot)
                .containerBackground(Color(Palette.background), for: .widget)
                .widgetURL(DeepLink.today.url)
        }
        .configurationDisplayName("Today")
        .description("Required tasks done and your Streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Entry: TimelineEntry {
    let snapshot: WidgetSnapshot
    var date: Date { snapshot.date }
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(snapshot: WidgetSnapshot(date: .now, requiredDone: 1, requiredTotal: 3, undoneRequiredTitles: ["Read", "Gym"], streak: 12, isKept: false))
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    /// One entry now, then one at each later Start Time and at midnight. The app and extensions also
    /// reload the timeline after every change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date()
        let tasks = store?.read(.tasks) ?? []
        let dates = [now] + WidgetSnapshot.refreshDates(tasks: tasks, now: now, calendar: .current)
        completion(Timeline(entries: dates.map(entry(at:)), policy: .atEnd))
    }

    private var store: LockInStore? { UserDefaultsStorage.appGroup().map { LockInStore(storage: $0) } }

    private func entry(at date: Date) -> Entry {
        guard let store else {
            return Entry(snapshot: WidgetSnapshot(date: date, requiredDone: 0, requiredTotal: 0, undoneRequiredTitles: [], streak: 0, isKept: true))
        }
        return Entry(snapshot: WidgetSnapshot.read(from: store, now: date))
    }
}

struct TodayWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private let primary = Color(Palette.primaryText)
    private let secondary = Color(Palette.secondaryText)
    private let accent = Color(Palette.accent)

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            summary
            if family == .systemMedium, !snapshot.undoneRequiredTitles.isEmpty {
                undoneList
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TODAY")
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(secondary)
            Spacer(minLength: 0)
            if snapshot.requiredTotal == 0 {
                Text("Free day")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(primary)
            } else {
                Text("\(snapshot.requiredDone)/\(snapshot.requiredTotal)")
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .foregroundStyle(snapshot.isKept ? accent : primary)
                    .contentTransition(.numericText())
                Text(snapshot.isKept ? "All done" : "required done")
                    .font(.footnote)
                    .foregroundStyle(secondary)
            }
            Spacer(minLength: 0)
            if snapshot.streak > 0 {
                Text("\(snapshot.streak)\u{2011}day streak")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var undoneList: some View {
        let shown = snapshot.undoneRequiredTitles.prefix(4)
        let hidden = snapshot.undoneRequiredTitles.count - shown.count
        return VStack(alignment: .leading, spacing: 6) {
            Text("LEFT")
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(secondary)
            ForEach(Array(shown.enumerated()), id: \.offset) { _, title in
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(primary)
                    .lineLimit(1)
            }
            if hidden > 0 {
                Text("+\(hidden) more")
                    .font(.footnote)
                    .foregroundStyle(secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private extension Color {
    init(_ rgb: Palette.RGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
