import WidgetKit
import SwiftUI

struct AyahOfDayEntry: TimelineEntry {
    let date: Date
    let ref: String
    let title: String
    let english: String
    let arabic: String
}

struct AyahOfDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> AyahOfDayEntry {
        AyahOfDayEntry(
            date: Date(),
            ref: "94:5",
            title: "With hardship, ease",
            english: "So truly where there is hardship there is also ease.",
            arabic: "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AyahOfDayEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahOfDayEntry>) -> Void) {
        let entry = load()
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 60))))
    }

    private func load() -> AyahOfDayEntry {
        let ref = WidgetDefaults.string("beummati.widget.ref") ?? "—"
        let title = WidgetDefaults.string("beummati.widget.title") ?? "Ayah of the day"
        let english = WidgetDefaults.string("beummati.widget.english")
            ?? "Open Be Ummati to refresh today’s ayah."
        let arabic = WidgetDefaults.string("beummati.widget.arabic") ?? ""
        return AyahOfDayEntry(date: Date(), ref: ref, title: title, english: english, arabic: arabic)
    }
}

struct AyahOfDayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: AyahOfDayEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AYAH OF THE DAY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetPalette.teal)
                .tracking(0.6)
            Text(entry.ref)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WidgetPalette.secondary)
            if !entry.arabic.isEmpty, family != .systemSmall {
                Text(entry.arabic)
                    .font(.system(size: 16))
                    .foregroundStyle(WidgetPalette.ink)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(3)
            }
            Text(entry.english)
                .font(.system(size: family == .systemSmall ? 13 : 14, weight: .regular, design: .serif))
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(family == .systemSmall ? 4 : 5)
            Spacer(minLength: 0)
        }
        .widgetCardBackground()
    }
}

struct AyahOfDayWidget: Widget {
    let kind = "BeUmmatiAyahOfDay"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AyahOfDayProvider()) { entry in
            AyahOfDayWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.parchment }
        }
        .configurationDisplayName("Ayah of the Day")
        .description("Today’s Qur’an reminder from Be Ummati.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
