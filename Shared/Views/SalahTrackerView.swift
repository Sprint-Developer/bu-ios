import SwiftUI

struct SalahTrackerView: View {
    @ObservedObject var tracker: SalahTracker
    @State private var selectedDay = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                streakCard
                todayCard
                weekCard
                Text("Tap a prayer to cycle: prayed → made up → missed → clear. Streaks count any day you showed up for at least one salah — progress, not perfection.")
                    .font(BeUmmatiTheme.ui(12))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
            }
            .padding(20)
        }
        .beUmmatiScreenBackground()
        .navigationTitle("Salah tracker")
    }

    private var streakCard: some View {
        let n = tracker.gentleStreak
        return VStack(alignment: .leading, spacing: 6) {
            Text("Gentle streak")
                .font(BeUmmatiTheme.ui(12, weight: .bold))
                .foregroundStyle(BeUmmatiTheme.brass)
            Text(n == 0 ? "Start today with one prayer" : "\(n) day\(n == 1 ? "" : "s") of showing up")
                .font(BeUmmatiTheme.heading(22))
                .foregroundStyle(BeUmmatiTheme.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .beUmmatiCard()
    }

    private var todayCard: some View {
        let log = tracker.log(for: selectedDay)
        return VStack(alignment: .leading, spacing: 12) {
            Text(Calendar.current.isDateInToday(selectedDay) ? "Today" : mediumDate(selectedDay))
                .font(BeUmmatiTheme.heading(18))
            ForEach(SalahName.allCases) { name in
                Button {
                    tracker.cycle(name, on: selectedDay)
                } label: {
                    HStack {
                        Image(systemName: log[name].symbol)
                            .foregroundStyle(color(for: log[name]))
                        Text(name.title)
                            .font(BeUmmatiTheme.ui(16, weight: .semibold))
                            .foregroundStyle(BeUmmatiTheme.ink)
                        Spacer()
                        Text(log[name].label)
                            .font(BeUmmatiTheme.ui(13, weight: .medium))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .beUmmatiCard()
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This week")
                .font(BeUmmatiTheme.heading(16))
            ForEach(tracker.weekDays(), id: \.date) { row in
                Button {
                    selectedDay = row.date
                } label: {
                    HStack {
                        Text(shortDay(row.date))
                            .font(BeUmmatiTheme.ui(13, weight: .semibold))
                            .frame(width: 40, alignment: .leading)
                        HStack(spacing: 6) {
                            ForEach(SalahName.allCases) { name in
                                Circle()
                                    .fill(dot(row.log[name]))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        Spacer()
                        Text("\(row.log.prayedCount)/5")
                            .font(BeUmmatiTheme.ui(12, weight: .bold))
                            .foregroundStyle(BeUmmatiTheme.teal)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        Calendar.current.isDate(row.date, inSameDayAs: selectedDay)
                            ? BeUmmatiTheme.tealSoft
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .beUmmatiCard()
    }

    private func color(for s: SalahStatus) -> Color {
        switch s {
        case .none: return BeUmmatiTheme.inkSecondary
        case .prayed: return BeUmmatiTheme.teal
        case .missed: return .secondary
        case .qada: return BeUmmatiTheme.brass
        }
    }

    private func dot(_ s: SalahStatus) -> Color {
        switch s {
        case .none: return Color.primary.opacity(0.12)
        case .prayed: return BeUmmatiTheme.teal
        case .missed: return Color.primary.opacity(0.25)
        case .qada: return BeUmmatiTheme.brass
        }
    }

    private func shortDay(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: d)
    }

    private func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }
}
