import WidgetKit
import SwiftUI

struct NextPrayerEntry: TimelineEntry {
    let date: Date
    let name: String
    let time: String
    let fire: Date?
    let hijri: String?
}

struct NextPrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextPrayerEntry {
        NextPrayerEntry(date: Date(), name: "Maghrib", time: "18:42", fire: Date().addingTimeInterval(3600), hijri: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextPrayerEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextPrayerEntry>) -> Void) {
        let entry = load()
        var dates: [Date] = [Date().addingTimeInterval(60)]
        if let fire = entry.fire, fire > Date() {
            dates.append(fire)
        }
        dates.append(Date().addingTimeInterval(15 * 60))
        let next = dates.min() ?? Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> NextPrayerEntry {
        let d = WidgetDefaults.suite
        let name = WidgetDefaults.string("beummati.widget.nextName") ?? "Next prayer"
        let time = WidgetDefaults.string("beummati.widget.nextTime") ?? "—"
        let hijri = WidgetDefaults.string("beummati.widget.hijri")
        let fireRaw = d.double(forKey: "beummati.widget.nextFire")
        let fire = fireRaw > 0 ? Date(timeIntervalSince1970: fireRaw) : nil
        return NextPrayerEntry(date: Date(), name: name, time: time, fire: fire, hijri: hijri)
    }
}

struct NextPrayerWidgetView: View {
    var entry: NextPrayerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEXT PRAYER")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetPalette.teal)
                .tracking(0.6)
            Text(entry.name)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(WidgetPalette.ink)
            Text(countdownLabel)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(WidgetPalette.secondary)
            Spacer(minLength: 0)
            HStack {
                Text(entry.time)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WidgetPalette.ink)
                Spacer()
                if let hijri = entry.hijri {
                    Text(hijri)
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetPalette.secondary)
                        .lineLimit(1)
                }
            }
        }
        .widgetCardBackground()
    }

    private var countdownLabel: String {
        guard let fire = entry.fire else { return "Open app for times" }
        let secs = Int(fire.timeIntervalSince(Date()))
        if secs <= 0 { return "Now" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "in \(h)h \(m)m" }
        return "in \(max(m, 1))m"
    }
}

struct NextPrayerWidget: Widget {
    let kind = "BeUmmatiNextPrayer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextPrayerProvider()) { entry in
            NextPrayerWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetPalette.parchment }
        }
        .configurationDisplayName("Next Prayer")
        .description("Countdown to the next salah.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
