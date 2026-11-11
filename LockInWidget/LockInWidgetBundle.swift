import SwiftUI
import WidgetKit
import LockInCore

@main
struct LockInWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
    }
}

/// Placeholder until ticket 020.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: Provider()) { _ in
            Text("LockIn")
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LockIn")
        .supportedFamilies([.systemSmall])
    }
}

private struct Provider: TimelineProvider {
    struct Entry: TimelineEntry { let date: Date }
    func placeholder(in context: Context) -> Entry { Entry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) { completion(Entry(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}
