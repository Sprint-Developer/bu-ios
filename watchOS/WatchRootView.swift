import SwiftUI

private enum WatchTheme {
    static let teal = Color(red: 0.12, green: 0.28, blue: 0.29)
    static let brass = Color(red: 0.78, green: 0.62, blue: 0.35)
    static let parchment = Color(red: 0.96, green: 0.94, blue: 0.90)
}

struct WatchRootView: View {
    @StateObject private var model = WatchPrayerModel()

    var body: some View {
        TabView {
            WatchTodayView(model: model)
            WatchPrayerListView(model: model)
            WatchDhikrView(model: model)
        }
        .tabViewStyle(.page)
        .onAppear { model.refresh() }
    }
}

struct WatchTodayView: View {
    @ObservedObject var model: WatchPrayerModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let next = model.nextPrayer() {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next · \(next.name)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text(model.countdown())
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(WatchTheme.brass)
                        Text(next.time)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WatchTheme.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text(model.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let day = model.day {
                    Text(day.hijri)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let r = model.reminder {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(r.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WatchTheme.brass)
                        Text(r.arabic)
                            .font(.system(size: 16))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        Text(r.english)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(r.ref)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WatchTheme.teal)
                    }
                    .padding(8)
                    .background(WatchTheme.parchment.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button("Next reminder") { model.rotateReminder() }
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Be Ummati")
    }
}

struct WatchPrayerListView: View {
    @ObservedObject var model: WatchPrayerModel

    var body: some View {
        List {
            if let day = model.day {
                Section(day.hijri) {
                    row("Fajr", day.fajr)
                    row("Dhuhr", day.dhuhr)
                    row("Asr", day.asr)
                    row("Maghrib", day.maghrib)
                    row("Isha", day.isha)
                }
            } else {
                Text(model.status)
            }
            Button("Refresh") { model.refresh() }
        }
        .navigationTitle("Prayer")
    }

    private func row(_ name: String, _ time: String) -> some View {
        let isNext = model.nextPrayer()?.name == name
        return HStack {
            Text(name)
                .fontWeight(isNext ? .bold : .regular)
            Spacer()
            Text(time)
                .fontWeight(.semibold)
                .foregroundStyle(isNext ? WatchTheme.brass : .primary)
        }
    }
}

struct WatchDhikrView: View {
    @ObservedObject var model: WatchPrayerModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Dhikr")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WatchTheme.brass)
            Text("\(model.dhikr)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.teal)
            Button {
                model.tapDhikr()
            } label: {
                Text("Tap")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WatchTheme.teal)
            Button("Reset") { model.resetDhikr() }
                .font(.caption2)
        }
        .padding()
        .navigationTitle("Dhikr")
    }
}
