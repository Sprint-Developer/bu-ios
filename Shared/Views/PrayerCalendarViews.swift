import SwiftUI

struct PrayerView: View {
    @ObservedObject var prayer: PrayerService
    @ObservedObject var notify: PrayerNotifications

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(prayer.cityLabel.isEmpty ? "Your location" : prayer.cityLabel)
                            .font(BeUmmatiTheme.ui(13, weight: .medium))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        if let day = prayer.day {
                            Text(day.gregorian.isEmpty ? day.hijriDate : day.gregorian)
                                .font(BeUmmatiTheme.heading(24))
                                .foregroundStyle(BeUmmatiTheme.ink)
                            Text(day.hijriDate)
                                .font(BeUmmatiTheme.ui(14))
                                .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        }
                    }

                    if let day = prayer.day {
                        VStack(spacing: 0) {
                            prayerRow("Fajr", day.fajr)
                            prayerRow("Sunrise", day.sunrise)
                            prayerRow("Dhuhr", day.dhuhr)
                            prayerRow("Asr", day.asr)
                            prayerRow("Maghrib", day.maghrib)
                            prayerRow("Isha", day.isha)
                        }
                        .beUmmatiCard()

                        NavigationLink {
                            QiblaView()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "location.north.line.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(BeUmmatiTheme.teal)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Qibla")
                                        .font(BeUmmatiTheme.heading(18))
                                        .foregroundStyle(BeUmmatiTheme.ink)
                                    Text("Point your phone toward Makkah")
                                        .font(BeUmmatiTheme.ui(13))
                                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            }
                            .padding(16)
                            .beUmmatiCard()
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(prayer.status)
                            .font(BeUmmatiTheme.ui(14))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            .padding(16)
                    }

                    NavigationLink {
                        PrayerNotifySettingsView(notify: notify, prayer: prayer)
                    } label: {
                        Label(notify.enabled ? "Alerts on" : "Set prayer alerts", systemImage: "bell.badge")
                            .font(BeUmmatiTheme.ui(15, weight: .semibold))
                            .foregroundStyle(BeUmmatiTheme.teal)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .beUmmatiCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .beUmmatiScreenBackground()
            .navigationTitle("Prayer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") { prayer.refresh() }
                }
            }
            .onAppear { prayer.refresh() }
        }
    }

    private func prayerRow(_ name: String, _ time: String) -> some View {
        let isNext = prayer.nextPrayer()?.name == name
        return HStack {
            Text(name)
                .font(BeUmmatiTheme.ui(16, weight: .semibold))
                .foregroundStyle(BeUmmatiTheme.ink)
            Spacer()
            Text(time)
                .font(BeUmmatiTheme.ui(18, weight: .bold))
                .foregroundStyle(isNext ? BeUmmatiTheme.teal : BeUmmatiTheme.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isNext ? BeUmmatiTheme.tealSoft : Color.clear)
        .overlay(alignment: .leading) {
            if isNext {
                Rectangle()
                    .fill(BeUmmatiTheme.teal)
                    .frame(width: 4)
            }
        }
    }
}

struct CalendarView: View {
    @ObservedObject var prayer: PrayerService
    @State private var monthDays: [(g: String, h: String)] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                if let day = prayer.day {
                    Section("Today") {
                        Text(day.hijriDate)
                            .font(.system(size: 22, weight: .bold))
                        Text("\(day.hijriWeekday) · \(day.gregorian)")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("This month (Hijri via Aladhan)") {
                    if loading {
                        ProgressView()
                    } else {
                        ForEach(Array(monthDays.enumerated()), id: \.offset) { _, row in
                            HStack {
                                Text(row.g).font(.system(size: 13, design: .rounded))
                                Spacer()
                                Text(row.h)
                                    .font(.system(size: 14, weight: .semibold))
                                    .environment(\.layoutDirection, .rightToLeft)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            .task { await loadMonth() }
            .refreshable { await loadMonth() }
        }
    }

    private func loadMonth() async {
        loading = true
        defer { loading = false }
        let cal = Calendar.current
        let now = Date()
        guard let range = cal.range(of: .day, in: .month, for: now) else { return }
        var rows: [(g: String, h: String)] = []
        let df = DateFormatter()
        df.dateFormat = "dd-MM-yyyy"
        let show = DateFormatter()
        show.dateStyle = .medium
        for day in range {
            var comps = cal.dateComponents([.year, .month], from: now)
            comps.day = day
            guard let date = cal.date(from: comps) else { continue }
            let key = df.string(from: date)
            if let hijri = await fetchHijri(date: key) {
                rows.append((show.string(from: date), hijri))
            }
        }
        monthDays = rows
    }

    private func fetchHijri(date: String) async -> String? {
        // Use conversion endpoint
        let url = URL(string: "https://api.aladhan.com/v1/gToH/\(date)")!
        var req = URLRequest(url: url)
        req.setValue(AppIdentity.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let hijri = dataObj["hijri"] as? [String: Any],
              let day = hijri["day"] as? String,
              let month = hijri["month"] as? [String: Any],
              let monthEn = month["en"] as? String,
              let year = hijri["year"] as? String
        else { return nil }
        return "\(day) \(monthEn) \(year)"
    }
}
