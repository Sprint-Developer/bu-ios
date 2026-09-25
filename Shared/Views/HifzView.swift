import SwiftUI

/// Hifz home — stats, review queue, surah progress. Mirrors Android HifzScreen.
struct HifzView: View {
    @ObservedObject private var store = HifzStore.shared
    @EnvironmentObject var reading: ReadingSettings
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var chapters: [QuranChapter] = []
    @State private var queueIndex = 0
    @State private var reviewAyah: QuranAyah?
    @State private var reviewLoading = false
    @State private var revealed = false
    @State private var loadError: String?

    private var reviewKey: String? {
        guard !store.dueToday.isEmpty else { return nil }
        let i = min(max(0, queueIndex), store.dueToday.count - 1)
        return store.dueToday[i]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statsCard
                goalChips
                quizModePicker
                reviewSection
                surahList
            }
            .padding(16)
            .padding(.bottom, 24)
            .frame(maxWidth: sizeClass == .regular ? 700 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .beUmmatiScreenBackground()
        .navigationTitle("Hifz")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadChapters() }
        .onChange(of: store.dueToday) { _, due in
            if due.isEmpty { queueIndex = 0 }
            else if queueIndex >= due.count { queueIndex = due.count - 1 }
        }
        .onChange(of: reviewKey) { _, _ in
            Task { await loadReview() }
        }
        .onChange(of: store.quizMode) { _, _ in
            revealed = false
            Task { await loadReview() }
        }
        .onAppear { Task { await loadReview() } }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MEMORIZED")
                        .font(BeUmmatiTheme.ui(11, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                    Text("\(store.stats.memorizedCount) ayahs")
                        .font(BeUmmatiTheme.ui(18, weight: .semibold))
                        .foregroundStyle(BeUmmatiTheme.ink)
                    if store.stats.streakDays > 0 {
                        Text("\(store.stats.streakDays)-day streak")
                            .font(BeUmmatiTheme.ui(12, weight: .medium))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DUE TODAY")
                        .font(BeUmmatiTheme.ui(11, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                    Text("\(store.stats.dueTodayCount)")
                        .font(BeUmmatiTheme.heading(28))
                        .foregroundStyle(BeUmmatiTheme.teal)
                }
            }
            Text(
                "Today’s goal: \(store.stats.markedTodayCount) / \(store.stats.dailyGoal) new · " +
                (store.stats.weakCount > 0 ? "\(store.stats.weakCount) weak" : "none weak")
            )
            .font(BeUmmatiTheme.ui(13))
            .foregroundStyle(BeUmmatiTheme.inkSecondary)

            ProgressView(
                value: Double(store.stats.markedTodayCount),
                total: Double(max(store.stats.dailyGoal, 1))
            )
            .tint(BeUmmatiTheme.teal)
        }
        .padding(16)
        .beUmmatiCard()
    }

    private var goalChips: some View {
        HStack(spacing: 8) {
            ForEach([3, 5, 10, 15], id: \.self) { goal in
                Button {
                    store.setDailyGoal(goal)
                } label: {
                    Text("\(goal)/day")
                        .font(BeUmmatiTheme.ui(13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            store.stats.dailyGoal == goal ? BeUmmatiTheme.teal : BeUmmatiTheme.tealSoft,
                            in: Capsule()
                        )
                        .foregroundStyle(store.stats.dailyGoal == goal ? .white : BeUmmatiTheme.teal)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var quizModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review mode")
                .font(BeUmmatiTheme.ui(12, weight: .bold))
                .foregroundStyle(BeUmmatiTheme.brass)
            Picker("Mode", selection: $store.quizMode) {
                ForEach(HifzQuizMode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            Text(store.quizMode.blurb)
                .font(BeUmmatiTheme.ui(12))
                .foregroundStyle(BeUmmatiTheme.inkSecondary)
        }
    }

    @ViewBuilder
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review queue")
                .font(BeUmmatiTheme.heading(18))
                .foregroundStyle(BeUmmatiTheme.ink)

            if store.dueToday.isEmpty {
                Text("Nothing due — mark ayahs while reading, or come back tomorrow.")
                    .font(BeUmmatiTheme.ui(14))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .beUmmatiCard()
            } else {
                Text("\(queueIndex + 1) of \(store.dueToday.count) · \(reviewKey ?? "")")
                    .font(BeUmmatiTheme.ui(13, weight: .medium))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)

                if reviewLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if let ayah = reviewAyah {
                    reviewCard(ayah)
                } else if let loadError {
                    Text(loadError)
                        .font(BeUmmatiTheme.ui(13))
                        .foregroundStyle(.red)
                }

                HStack(spacing: 10) {
                    Button("Previous") {
                        queueIndex = max(0, queueIndex - 1)
                    }
                    .disabled(queueIndex <= 0)
                    Spacer()
                    Button("Next") {
                        queueIndex = min(store.dueToday.count - 1, queueIndex + 1)
                    }
                    .disabled(queueIndex >= store.dueToday.count - 1)
                }
                .font(BeUmmatiTheme.ui(14, weight: .semibold))
                .foregroundStyle(BeUmmatiTheme.teal)
            }
        }
    }

    private func reviewCard(_ ayah: QuranAyah) -> some View {
        let ar = ayah.arabic(for: reading.arabicFont)
        return VStack(alignment: .leading, spacing: 12) {
            if store.quizMode == .showArabic || revealed {
                Text(ar)
                    .font(reading.arabicFont.font(size: reading.arabicSize))
                    .foregroundStyle(reading.arabicColor)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            } else if store.quizMode == .audioOnly {
                Text("Listen, then reveal")
                    .font(BeUmmatiTheme.ui(15, weight: .medium))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
            } else {
                Text("Recall the ayah…")
                    .font(BeUmmatiTheme.ui(15, weight: .medium))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
            }

            if revealed || store.quizMode == .showArabic {
                if reading.showEnglish, !ayah.english.isEmpty {
                    Text(ayah.english)
                        .font(reading.englishFont.font(size: reading.englishSize))
                        .foregroundStyle(reading.englishColor)
                }
                if reading.showUrdu, !ayah.urdu.isEmpty {
                    Text(ayah.urdu)
                        .font(reading.urduFont.font(size: reading.urduSize))
                        .foregroundStyle(reading.urduColor)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }

            if !revealed && store.quizMode != .showArabic {
                Button("Reveal") { revealed = true }
                    .font(BeUmmatiTheme.ui(15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BeUmmatiTheme.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 10) {
                Button {
                    guard let key = reviewKey else { return }
                    store.recordReview(key: key, remembered: true)
                    revealed = false
                    advanceAfterReview()
                } label: {
                    Text("Remembered")
                        .font(BeUmmatiTheme.ui(14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(BeUmmatiTheme.tealSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    guard let key = reviewKey else { return }
                    store.recordReview(key: key, remembered: false)
                    revealed = false
                    advanceAfterReview()
                } label: {
                    Text("Forgot")
                        .font(BeUmmatiTheme.ui(14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(BeUmmatiTheme.teal)

            HStack {
                Button("Flag weak") {
                    if let key = reviewKey { store.flagWeak(key) }
                }
                Spacer()
                Button("Unmark", role: .destructive) {
                    if let key = reviewKey {
                        store.unmark(key)
                        revealed = false
                    }
                }
            }
            .font(BeUmmatiTheme.ui(13, weight: .semibold))
        }
        .padding(16)
        .beUmmatiCard()
    }

    private var surahList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("By surah")
                .font(BeUmmatiTheme.heading(18))
                .foregroundStyle(BeUmmatiTheme.ink)

            ForEach(chapters) { ch in
                let done = store.memorizedInSurah(ch.id)
                let progress = store.progressForSurah(ch.id, ayahCount: ch.versesCount)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(ch.id). \(ch.nameSimple)")
                            .font(BeUmmatiTheme.ui(15, weight: .semibold))
                            .foregroundStyle(BeUmmatiTheme.ink)
                        Text(ch.nameArabic)
                            .font(.custom("Amiri-Regular", size: 16))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        ProgressView(value: Double(progress))
                            .tint(BeUmmatiTheme.teal)
                        Text("\(done)/\(ch.versesCount)")
                            .font(BeUmmatiTheme.ui(12))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    }
                    Spacer()
                    Menu {
                        Button("Mark all memorized") {
                            store.markSurahMemorized(surah: ch.id, ayahCount: ch.versesCount)
                        }
                        Button("Clear surah", role: .destructive) {
                            store.unmarkSurah(ch.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(BeUmmatiTheme.teal)
                    }
                }
                .padding(14)
                .beUmmatiCard()
            }
        }
    }

    private func advanceAfterReview() {
        if queueIndex < store.dueToday.count - 1 {
            queueIndex += 1
        }
    }

    private func loadChapters() async {
        chapters = (try? await QuranAPI.shared.chapters()) ?? []
    }

    private func loadReview() async {
        guard let key = reviewKey else {
            reviewAyah = nil
            return
        }
        revealed = false
        reviewLoading = true
        loadError = nil
        defer { reviewLoading = false }
        do {
            reviewAyah = try await QuranAPI.shared.verse(key: key)
        } catch {
            reviewAyah = nil
            loadError = "Couldn’t load \(key). Check connection or offline pack."
        }
    }
}
