import WidgetKit
import SwiftUI

struct LastReadingEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let kind: String
}

struct LastReadingProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastReadingEntry {
        LastReadingEntry(date: Date(), title: "Al-Baqarah", subtitle: "Surah 2", kind: "quran")
    }

    func getSnapshot(in context: Context, completion: @escaping (LastReadingEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastReadingEntry>) -> Void) {
        let entry = load()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }

    private func load() -> LastReadingEntry {
        let title = WidgetDefaults.string("beummati.widget.lastTitle") ?? "Continue reading"
        let subtitle = WidgetDefaults.string("beummati.widget.lastSubtitle")
            ?? "Open a surah or lecture in the app"
        let kind = WidgetDefaults.string("beummati.widget.lastKind") ?? "quran"
        return LastReadingEntry(date: Date(), title: title, subtitle: subtitle, kind: kind)
    }
}

struct LastReadingWidgetView: View {
    var entry: LastReadingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LAST READING")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetPalette.teal)
                .tracking(0.6)
            Text(entry.title)
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(2)
            Text(entry.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WidgetPalette.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Label(entry.kind == "library" ? "Lecture" : "Qur’an", systemImage: entry.kind == "library" ? "headphones" : "book")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetPalette.teal)
        }
        .widgetCardBackground()
    }
}

struct LastReadingWidget: Widget {
    let kind = "BeUmmatiLastReading"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastReadingProvider()) { entry in
            LastReadingWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.parchment }
        }
        .configurationDisplayName("Last Reading")
        .description("Pick up where you left off.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
