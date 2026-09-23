import SwiftUI
import Combine

struct HomeView: View {
    @ObservedObject var reminders: ReminderStore
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var plan: DailyPlanStore
    @ObservedObject var prayer: PrayerService
    @ObservedObject var reading: ReadingSettings
    @ObservedObject var notify: PrayerNotifications
    @ObservedObject var salah: SalahTracker
    @AppStorage("beummati.displayName") private var displayName = ""
    @AppStorage("beummati.series.reminderFilter") private var seriesFilter = "all"
    @ObservedObject private var libraryProgress = LibraryProgressStore.shared
    @ObservedObject private var audio = LectureAudioSession.shared
    @ObservedObject private var listenStats = LectureListenStats.shared
    @EnvironmentObject private var bookmarks: BookmarkStore
    @EnvironmentObject private var theme: ThemeStore
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    nextPrayerCard
                    continueListeningCard
                    seriesContinueCard
                    prayerRow
                    salahStrip
                    reminderLanes
                    dailyPlanStrip
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .beUmmatiScreenBackground()
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        reminders.refresh()
                    } label: {
                        Image(systemName: "sparkles")
                    }
                }
            }
            .onAppear {
                plan.rollIfNeeded()
                plan.markReminderRead()
                if reminders.series == nil {
                    reminders.refresh(lane: .series)
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    MoreSettings()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showSettings = false }
                            }
                        }
                }
                .environmentObject(reading)
                .environmentObject(bookmarks)
                .environmentObject(theme)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Assalamu alaikum wa rehmatullahi wa barakatuh")
                .font(BeUmmatiTheme.heading(22))
                .foregroundStyle(BeUmmatiTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if !displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(displayName.trimmingCharacters(in: .whitespaces))
                    .font(BeUmmatiTheme.heading(26))
                    .foregroundStyle(BeUmmatiTheme.teal)
            }
            if let day = prayer.day {
                Text("\(day.hijriDate)  ·  \(day.gregorian)")
                    .font(BeUmmatiTheme.ui(13, weight: .medium))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
            } else {
                // Prayer status lives on the card below — keep a date here regardless.
                Text(Date().formatted(date: .long, time: .omitted))
                    .font(BeUmmatiTheme.ui(13, weight: .medium))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nextPrayerCard: some View {
        NextPrayerCard(prayer: prayer)
    }

    @ViewBuilder
    private var continueListeningCard: some View {
        let week = listenStats.finishedThisWeek
        let streak = audio.listeningStreakDays
        if let session = audio.lastSession(),
           let series = LibraryCatalog.series(id: session.seriesID),
           let chapter = series.chapters?.first(where: { $0.id == session.chapterID }),
           let track = LectureAudioCatalog.track(seriesID: series.id, chapterID: chapter.id) {
            Button {
                audio.play(series: series, chapter: chapter, track: track)
                audio.showFullPlayer = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Continue listening")
                            .font(BeUmmatiTheme.ui(12, weight: .bold))
                            .foregroundStyle(BeUmmatiTheme.brass)
                        Spacer()
                        Image(systemName: "waveform")
                            .foregroundStyle(BeUmmatiTheme.teal)
                    }
                    Text(chapter.title)
                        .font(BeUmmatiTheme.heading(16))
                        .foregroundStyle(BeUmmatiTheme.ink)
                        .lineLimit(2)
                    Text(series.title)
                        .font(BeUmmatiTheme.ui(13))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    HStack(spacing: 12) {
                        if streak > 0 {
                            Label("\(streak)-day streak", systemImage: "flame.fill")
                        }
                        if week > 0 {
                            Label("\(week) finished this week", systemImage: "checkmark.circle")
                        }
                        Spacer()
                        Text(formatListenTime(session.time))
                            .font(BeUmmatiTheme.ui(12, weight: .bold).monospacedDigit())
                    }
                    .font(BeUmmatiTheme.ui(12, weight: .semibold))
                    .foregroundStyle(BeUmmatiTheme.teal)
                }
                .padding(16)
                .beUmmatiCard()
            }
            .buttonStyle(.plain)
        } else if streak > 0 || week > 0 {
            HStack {
                if streak > 0 {
                    Label("\(streak)-day listen streak", systemImage: "flame.fill")
                }
                if week > 0 {
                    Label("\(week) lectures this week", systemImage: "checkmark.circle")
                }
            }
            .font(BeUmmatiTheme.ui(13, weight: .semibold))
            .foregroundStyle(BeUmmatiTheme.teal)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .beUmmatiCard()
        }
    }

    private func formatListenTime(_ t: TimeInterval) -> String {
        let s = Int(max(0, t).rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    @ViewBuilder
    private var seriesContinueCard: some View {
        if let series = libraryProgress.primarySeries(),
           let chapter = libraryProgress.resumeChapter(in: series) {
            let total = series.chapterCount
            let n = libraryProgress.progressCount(seriesID: series.id, total: total)
            NavigationLink {
                LibraryChapterReaderView(series: series, chapter: chapter)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Continue learning")
                            .font(BeUmmatiTheme.ui(12, weight: .bold))
                            .foregroundStyle(BeUmmatiTheme.brass)
                        Spacer()
                        Text("\(n)/\(total)")
                            .font(BeUmmatiTheme.ui(12, weight: .bold))
                            .foregroundStyle(BeUmmatiTheme.teal)
                    }
                    Text(series.title)
                        .font(BeUmmatiTheme.heading(16))
                        .foregroundStyle(BeUmmatiTheme.ink)
                    Text(chapter.title)
                        .font(BeUmmatiTheme.ui(14))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        .lineLimit(2)
                    if let snip = reminders.series {
                        Text(snip.english)
                            .font(BeUmmatiTheme.ui(13))
                            .foregroundStyle(BeUmmatiTheme.ink)
                            .lineLimit(3)
                    }
                }
                .padding(16)
                .beUmmatiCard()
            }
            .buttonStyle(.plain)
        }
    }

    private var prayerRow: some View {
        Group {
            if let day = prayer.day {
                let nextName = prayer.nextPrayer()?.name
                HStack(spacing: 0) {
                    ForEach(
                        [("Fajr", day.fajr), ("Dhuhr", day.dhuhr), ("Asr", day.asr), ("Maghrib", day.maghrib), ("Isha", day.isha)],
                        id: \.0
                    ) { name, time in
                        let isNext = nextName == name
                        VStack(spacing: 4) {
                            Text(name)
                                .font(BeUmmatiTheme.ui(10, weight: .semibold))
                                .foregroundStyle(isNext ? BeUmmatiTheme.teal : BeUmmatiTheme.inkSecondary)
                            Text(time)
                                .font(BeUmmatiTheme.ui(12, weight: .bold))
                                .foregroundStyle(isNext ? BeUmmatiTheme.teal : BeUmmatiTheme.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isNext ? BeUmmatiTheme.tealSoft : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(6)
                .beUmmatiCard()
            }
        }
    }

    private var salahStrip: some View {
        let today = salah.log()
        let streak = salah.gentleStreak
        return NavigationLink {
            SalahTrackerView(tracker: salah)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Salah")
                        .font(BeUmmatiTheme.ui(12, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                    Text(streak == 0 ? "Log today’s prayers" : "\(streak)-day gentle streak")
                        .font(BeUmmatiTheme.ui(15, weight: .semibold))
                        .foregroundStyle(BeUmmatiTheme.ink)
                }
                Spacer()
                Text("\(today.prayedCount)/5")
                    .font(BeUmmatiTheme.ui(16, weight: .bold))
                    .foregroundStyle(BeUmmatiTheme.teal)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
            }
            .padding(16)
            .beUmmatiCard()
        }
        .buttonStyle(.plain)
    }

    private var reminderLanes: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today’s reminders")
                .font(BeUmmatiTheme.heading(18))
                .foregroundStyle(BeUmmatiTheme.ink)

            Picker("Series filter", selection: $seriesFilter) {
                Text("All series").tag("all")
                Text("Seerah").tag("seerah")
                Text("Prophets").tag("prophets")
                Text("Abu Bakr").tag("abu-bakr")
                Text("Umar").tag("umar")
            }
            .pickerStyle(.menu)
            .onChange(of: seriesFilter) { _, _ in
                reminders.refresh(lane: .series)
            }

            ForEach(ReminderLane.allCases) { lane in
                reminderLaneCard(lane)
            }
        }
    }

    @ViewBuilder
    private func reminderLaneCard(_ lane: ReminderLane) -> some View {
        let item = reminders.item(for: lane)
        let isLoading = reminders.loadingLanes.contains(lane) && item == nil

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(lane.rawValue, systemImage: lane.icon)
                    .font(BeUmmatiTheme.ui(12, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(BeUmmatiTheme.brass)
                Spacer()
                if let item {
                    Text(item.ref)
                        .font(BeUmmatiTheme.ui(11, weight: .medium))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        .lineLimit(1)
                }
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if let item {
                if !item.title.isEmpty {
                    Text(item.title)
                        .font(BeUmmatiTheme.heading(17))
                        .foregroundStyle(BeUmmatiTheme.ink)
                        .lineLimit(2)
                }
                TripleText(arabic: item.arabic, english: item.english, urdu: item.urdu)

                HStack(spacing: 10) {
                    NavigationLink {
                        ReminderLaneDetailView(
                            lane: lane,
                            reminders: reminders,
                            notes: notes,
                            bookmarks: bookmarks,
                            plan: plan
                        )
                    } label: {
                        HStack {
                            Text("Open")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .font(BeUmmatiTheme.ui(13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(BeUmmatiTheme.teal, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        reminders.refresh(lane: lane)
                    } label: {
                        Text("Next")
                            .font(BeUmmatiTheme.ui(13, weight: .bold))
                            .foregroundStyle(BeUmmatiTheme.teal)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            } else {
                Text("Tap Next to load a \(lane.rawValue.lowercased()) reminder.")
                    .font(BeUmmatiTheme.ui(13))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                Button("Next") { reminders.refresh(lane: lane) }
                    .font(BeUmmatiTheme.ui(13, weight: .bold))
                    .foregroundStyle(BeUmmatiTheme.teal)
            }
        }
        .padding(16)
        .beUmmatiCard()
    }

    private var dailyPlanStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today’s reading")
                    .font(BeUmmatiTheme.heading(16))
                Spacer()
                Text("\(plan.doneAyahs)/\(plan.goalAyahs)")
                    .font(BeUmmatiTheme.ui(13, weight: .semibold))
                    .foregroundStyle(BeUmmatiTheme.teal)
            }
            ProgressView(value: plan.progress)
                .tint(BeUmmatiTheme.brass)
            Text("Open a surah to count toward your goal · adjust goal in settings later")
                .font(BeUmmatiTheme.ui(11))
                .foregroundStyle(BeUmmatiTheme.inkSecondary)
        }
        .padding(16)
        .beUmmatiCard()
    }

}

/// Next-prayer countdown. Owns its own tick so only this card redraws each minute,
/// and re-reads `nextPrayerFire()` so the number keeps moving as prayers pass.
private struct NextPrayerCard: View {
    @ObservedObject var prayer: PrayerService
    @State private var now = Date()

    private let tick = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    var body: some View {
        let next = prayer.nextPrayerFire()
        VStack(alignment: .leading, spacing: 10) {
            Text(next.map { "Next — \($0.name)" } ?? "Prayer times")
                .font(BeUmmatiTheme.ui(14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(countdown(to: next?.fire))
                .font(BeUmmatiTheme.heading(42))
                .foregroundStyle(BeUmmatiTheme.brass)
                .contentTransition(.numericText())
            if let next {
                HStack(spacing: 8) {
                    Text(next.time)
                    if prayer.usingFallbackLocation {
                        Text("· Dubai")
                    }
                }
                .font(BeUmmatiTheme.ui(15, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            } else {
                Text(prayer.status)
                    .font(BeUmmatiTheme.ui(13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry") { prayer.refresh() }
                    .font(BeUmmatiTheme.ui(13, weight: .bold))
                    .foregroundStyle(BeUmmatiTheme.brass)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BeUmmatiTheme.teal, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: BeUmmatiTheme.teal.opacity(0.35), radius: 16, y: 8)
        .onReceive(tick) { now = $0 }
    }

    private func countdown(to fire: Date?) -> String {
        guard let fire else { return "—" }
        let secs = max(0, Int(fire.timeIntervalSince(now)))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "now"
    }
}
