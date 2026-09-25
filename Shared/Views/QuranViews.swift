import SwiftUI

enum QuranReadMode: String, CaseIterable, Identifiable {
    case mushaf = "Qur’an only"
    case study = "With translation"
    var id: String { rawValue }
}

private enum QuranBrowseTab: String, CaseIterable, Identifiable {
    case surah = "Surah"
    case parah = "Parah"
    var id: String { rawValue }
}

struct QuranListView: View {
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var plan: DailyPlanStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var chapters: [QuranChapter] = []
    @State private var error: String?
    @State private var loading = true
    @State private var offlineIDs: Set<Int> = []
    @State private var browseTab: QuranBrowseTab = .surah

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Browse", selection: $browseTab) {
                    ForEach(QuranBrowseTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Group {
                    if browseTab == .surah {
                        surahContent
                    } else {
                        parahContent
                    }
                }
            }
            .frame(maxWidth: sizeClass == .regular ? 700 : .infinity)
            .frame(maxWidth: .infinity)
            .navigationTitle("Qur’an")
            .background(BeUmmatiTheme.parchment)
            .navigationDestination(for: QuranChapter.self) { ch in
                SurahDetailView(chapter: ch, notes: notes, bookmarks: bookmarks, plan: plan)
            }
            .navigationDestination(for: JuzInfo.self) { juz in
                JuzDetailView(juz: juz, notes: notes, bookmarks: bookmarks, plan: plan)
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private var surahContent: some View {
        if loading {
            ProgressView("Loading surahs…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error {
            ContentUnavailableView("Couldn’t load", systemImage: "wifi.exclamationmark", description: Text(error))
        } else {
            List(chapters) { ch in
                NavigationLink(value: ch) {
                    HStack {
                        Text("\(ch.id)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(BeUmmatiTheme.teal)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(ch.nameSimple).font(BeUmmatiTheme.heading(17))
                                if offlineIDs.contains(ch.id) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(BeUmmatiTheme.teal)
                                }
                            }
                            Text("\(ch.versesCount) ayahs · \(ch.revelationPlace)")
                                .font(BeUmmatiTheme.ui(12))
                                .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        }
                        Spacer()
                        Text(ch.nameArabic)
                            .font(.custom("Amiri-Regular", size: 20))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var parahContent: some View {
        List(JuzCatalog.all) { juz in
            NavigationLink(value: juz) {
                HStack {
                    Text("\(juz.number)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(BeUmmatiTheme.teal)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(juz.titleEnglish).font(BeUmmatiTheme.heading(17))
                        Text("\(juz.startSurahName) · \(juz.rangeLabel)")
                            .font(BeUmmatiTheme.ui(12))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    }
                    Spacer()
                    Text(juz.titleUrdu)
                        .font(.custom("Amiri-Regular", size: 18))
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func load() async {
        loading = chapters.isEmpty
        do {
            chapters = try await QuranAPI.shared.chapters()
            offlineIDs = Set(await OfflineCache.shared.cachedSurahIDs())
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct SurahDetailView: View {
    let chapter: QuranChapter
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var plan: DailyPlanStore
    /// Optional ayah key e.g. "2:255" — scrolls there after load.
    var initialAyahKey: String? = nil
    @EnvironmentObject var reading: ReadingSettings
    @ObservedObject private var audio = QuranAyahPlayer.shared
    @State private var ayahs: [QuranAyah] = []
    @State private var loading = true
    @State private var mode: QuranReadMode = .mushaf
    @State private var counted = false
    @State private var showJump = false
    @State private var jumpText = ""
    @State private var scrollToAyah: String?
    @State private var wordsKey: String?
    @AppStorage("beummati.quranReadMode") private var savedMode = QuranReadMode.mushaf.rawValue

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading…")
            } else if mode == .mushaf {
                mushafReader
            } else {
                studyReader
            }
        }
        .navigationTitle(chapter.nameArabic.isEmpty ? chapter.nameSimple : chapter.nameArabic)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    audioToolbarButton
                    Button { showJump = true } label: {
                        Image(systemName: "arrow.right.circle")
                    }
                    Picker("Mode", selection: $mode) {
                        ForEach(QuranReadMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .alert("Go to ayah #", isPresented: $showJump) {
            TextField("1–\(chapter.versesCount)", text: $jumpText)
                .keyboardType(.numberPad)
            Button("Go") {
                if let n = Int(jumpText), n >= 1, n <= chapter.versesCount {
                    scrollToAyah = "\(chapter.id):\(n)"
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Jump within \(chapter.nameSimple)")
        }
        .onAppear {
            if let m = QuranReadMode(rawValue: savedMode) { mode = m }
        }
        .onChange(of: mode) { _, new in
            savedMode = new.rawValue
        }
        .sheet(isPresented: Binding(
            get: { wordsKey != nil },
            set: { if !$0 { wordsKey = nil } }
        )) {
            NavigationStack {
                if let wordsKey {
                    WordByWordView(ayahKey: wordsKey)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { self.wordsKey = nil }
                            }
                        }
                }
            }
        }
        .task {
            loading = true
            WidgetSnapshot.writeLastReading(
                title: chapter.nameSimple,
                subtitle: "Surah \(chapter.id) · \(chapter.versesCount) ayahs",
                kind: "quran"
            )
            ayahs = (try? await QuranAPI.shared.ayahs(chapter: chapter.id)) ?? []
            loading = false
            if let key = initialAyahKey {
                mode = .study
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    scrollToAyah = key
                }
            }
            if !counted, !ayahs.isEmpty {
                counted = true
                plan.addAyahProgress(1)
            }
        }
    }

    @ViewBuilder
    private var audioToolbarButton: some View {
        let activeHere = audio.state.surah == chapter.id && audio.state.surah > 0
        Button {
            if activeHere && (audio.state.playing || audio.state.loading) {
                audio.toggle()
            } else if !ayahs.isEmpty {
                audio.playSurah(ayahs, startAyah: 1)
            }
        } label: {
            Image(systemName: activeHere && audio.state.playing ? "pause.fill" : "play.fill")
        }
        .disabled(ayahs.isEmpty)
        .accessibilityLabel(activeHere && audio.state.playing ? "Pause recitation" : "Play surah")
    }

    private var mushafReader: some View {
        ZoomableScrollView(minZoom: 1, maxZoom: 3) {
            VStack(spacing: 12) {
                Text(chapter.nameArabic)
                    .font(reading.arabicFont.font(size: reading.arabicSize + 4))
                    .foregroundStyle(reading.arabicColor)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .beUmmatiSelectableText()

                if chapter.id != 1 && chapter.id != 9 {
                    Text(bismillah)
                        .font(reading.arabicFont.font(size: reading.arabicSize))
                        .foregroundStyle(reading.arabicColor)
                        .lineSpacing(reading.arabicLineSpacing)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.bottom, 4)
                        .beUmmatiSelectableText()
                }

                ForEach(ayahs) { a in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(a.arabic(for: reading.arabicFont))
                            .font(reading.arabicFont.font(size: reading.arabicSize))
                            .foregroundStyle(audio.state.key == a.key ? BeUmmatiTheme.teal : reading.arabicColor)
                            .lineSpacing(reading.arabicLineSpacing)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .beUmmatiSelectableText()

                        Text(ayahNumber(a.key))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(BeUmmatiTheme.brass)
                            .frame(width: 28, height: 28)
                            .background(Circle().stroke(BeUmmatiTheme.brass.opacity(0.7), lineWidth: 1))
                    }
                    .padding(.vertical, 2)
                    .id(a.key)
                    .contextMenu {
                        ayahActions(a)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .leftToRight)
        }
        .background(BeUmmatiTheme.parchment)
        .onChange(of: scrollToAyah) { _, _ in
            // Zoomable UIScrollView does not participate in ScrollViewReader; clear request.
            scrollToAyah = nil
        }
    }

    private var bismillah: String {
        switch reading.arabicFont {
        case .indoPak, .mehrNastaliq, .notoNastaliq, .gulzar:
            return "بِسۡمِ اللهِ الرَّحۡمٰنِ الرَّحِيۡمِ"
        default:
            return "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ"
        }
    }

    private func ayahNumber(_ key: String) -> String {
        key.split(separator: ":").last.map(String.init) ?? ""
    }

    private var studyReader: some View {
        ScrollViewReader { proxy in
            List(ayahs) { a in
                let ar = a.arabic(for: reading.arabicFont)
                let related = RelatedVerses.related(to: a.key)
                let isPlaying = audio.state.key == a.key
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(a.key)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(BeUmmatiTheme.brass)
                        if isPlaying {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(BeUmmatiTheme.teal)
                        }
                    }
                    TripleText(arabic: ar, english: a.english, urdu: a.urdu)
                    if !related.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("See also")
                                .font(BeUmmatiTheme.ui(11, weight: .bold))
                                .foregroundStyle(BeUmmatiTheme.brass)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(related, id: \.self) { key in
                                        NavigationLink {
                                            RelatedAyahDestination(key: key, notes: notes, bookmarks: bookmarks, plan: plan)
                                        } label: {
                                            Text(key)
                                                .font(BeUmmatiTheme.ui(12, weight: .semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(BeUmmatiTheme.tealSoft, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        BeUmmatiShareButton(kind: "Qur’an", ref: a.key, arabic: ar, english: a.english, urdu: a.urdu)
                        GiftReminderButton(kind: "Qur’an", ref: a.key, arabic: ar, english: a.english, urdu: a.urdu)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeUmmatiTheme.teal)
                    HStack {
                        Button {
                            audio.play(from: a, in: ayahs)
                        } label: {
                            Label("Play", systemImage: "play.circle")
                        }
                        .buttonStyle(.plain)
                        Button {
                            wordsKey = a.key
                        } label: {
                            Label("Words", systemImage: "textformat.abc")
                        }
                        .buttonStyle(.plain)
                        Button {
                            let hifz = HifzStore.shared
                            if hifz.isMemorized(a.key) {
                                hifz.unmark(a.key)
                            } else {
                                hifz.markMemorized(a.key)
                                _ = hifz.consumeFirstMemorizeHint()
                            }
                        } label: {
                            Label(
                                HifzStore.shared.isMemorized(a.key) ? "Memorized" : "Hifz",
                                systemImage: HifzStore.shared.isMemorized(a.key) ? "brain.head.profile.fill" : "brain.head.profile"
                            )
                        }
                        .buttonStyle(.plain)
                        Button {
                            notes.add(title: "Ayah \(a.key)", body: "\(ar)\n\n\(a.english)\n\n\(a.urdu)", ref: a.key, linkKind: "Qur’an")
                        } label: {
                            Label("Note", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.plain)
                        Button {
                            bookmarks.toggle(kind: "Qur’an", ref: a.key, title: "Ayah \(a.key)", arabic: ar, english: a.english, urdu: a.urdu)
                        } label: {
                            Label(
                                bookmarks.isBookmarked(kind: "Qur’an", ref: a.key) ? "Saved" : "Save",
                                systemImage: bookmarks.isBookmarked(kind: "Qur’an", ref: a.key) ? "bookmark.fill" : "bookmark"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeUmmatiTheme.teal)
                }
                .padding(.vertical, 6)
                .id(a.key)
            }
            .scrollContentBackground(.hidden)
            .background(BeUmmatiTheme.parchment)
            .onChange(of: scrollToAyah) { _, key in
                guard let key else { return }
                withAnimation { proxy.scrollTo(key, anchor: .top) }
                scrollToAyah = nil
            }
        }
    }

    @ViewBuilder
    private func ayahActions(_ a: QuranAyah) -> some View {
        let ar = a.arabic(for: reading.arabicFont)
        Button {
            audio.play(from: a, in: ayahs)
        } label: {
            Label("Play from here", systemImage: "play.circle")
        }
        Button {
            wordsKey = a.key
        } label: {
            Label("Word by word", systemImage: "textformat.abc")
        }
        Button {
            bookmarks.toggle(kind: "Qur’an", ref: a.key, title: "Ayah \(a.key)", arabic: ar, english: a.english, urdu: a.urdu)
        } label: {
            Label(bookmarks.isBookmarked(kind: "Qur’an", ref: a.key) ? "Remove bookmark" : "Bookmark", systemImage: "bookmark")
        }
        Button {
            notes.add(title: "Ayah \(a.key)", body: "\(ar)\n\n\(a.english)\n\n\(a.urdu)", ref: a.key, linkKind: "Qur’an")
        } label: {
            Label("Add note", systemImage: "square.and.pencil")
        }
    }
}

/// Parah / juz reader — loads `verses/by_juz/{n}` and reuses mushaf / study patterns.
struct JuzDetailView: View {
    let juz: JuzInfo
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var plan: DailyPlanStore
    @EnvironmentObject var reading: ReadingSettings
    @ObservedObject private var audio = QuranAyahPlayer.shared
    @State private var ayahs: [QuranAyah] = []
    @State private var loading = true
    @State private var error: String?
    @State private var mode: QuranReadMode = .mushaf
    @State private var wordsKey: String?
    @AppStorage("beummati.quranReadMode") private var savedMode = QuranReadMode.mushaf.rawValue

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading parah…")
            } else if let error {
                ContentUnavailableView("Couldn’t load", systemImage: "wifi.exclamationmark", description: Text(error))
            } else if mode == .mushaf {
                mushafReader
            } else {
                studyReader
            }
        }
        .navigationTitle(juz.titleUrdu)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        if audio.state.playing || audio.state.loading {
                            audio.toggle()
                        } else if let first = ayahs.first {
                            audio.play(from: first, in: ayahs)
                        }
                    } label: {
                        Image(systemName: audio.state.playing ? "pause.fill" : "play.fill")
                    }
                    .disabled(ayahs.isEmpty)
                    Picker("Mode", selection: $mode) {
                        ForEach(QuranReadMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .onAppear {
            if let m = QuranReadMode(rawValue: savedMode) { mode = m }
        }
        .onChange(of: mode) { _, new in
            savedMode = new.rawValue
        }
        .sheet(isPresented: Binding(
            get: { wordsKey != nil },
            set: { if !$0 { wordsKey = nil } }
        )) {
            NavigationStack {
                if let wordsKey {
                    WordByWordView(ayahKey: wordsKey)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { self.wordsKey = nil }
                            }
                        }
                }
            }
        }
        .task {
            loading = true
            error = nil
            do {
                ayahs = try await QuranAPI.shared.ayahs(juz: juz.number)
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private var mushafReader: some View {
        ZoomableScrollView(minZoom: 1, maxZoom: 3) {
            VStack(spacing: 12) {
                Text(juz.titleEnglish)
                    .font(BeUmmatiTheme.ui(13, weight: .semibold))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(juz.rangeLabel)
                    .font(BeUmmatiTheme.ui(12))
                    .foregroundStyle(BeUmmatiTheme.brass)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(ayahs) { a in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(a.arabic(for: reading.arabicFont))
                            .font(reading.arabicFont.font(size: reading.arabicSize))
                            .foregroundStyle(audio.state.key == a.key ? BeUmmatiTheme.teal : reading.arabicColor)
                            .lineSpacing(reading.arabicLineSpacing)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .beUmmatiSelectableText()

                        Text(a.key)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(BeUmmatiTheme.brass)
                            .frame(width: 44)
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button {
                            audio.play(from: a, in: ayahs)
                        } label: {
                            Label("Play from here", systemImage: "play.circle")
                        }
                        Button {
                            wordsKey = a.key
                        } label: {
                            Label("Word by word", systemImage: "textformat.abc")
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .leftToRight)
        }
        .background(BeUmmatiTheme.parchment)
    }

    private var studyReader: some View {
        List(ayahs) { a in
            let ar = a.arabic(for: reading.arabicFont)
            VStack(alignment: .leading, spacing: 10) {
                Text(a.key)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(BeUmmatiTheme.brass)
                TripleText(arabic: ar, english: a.english, urdu: a.urdu)
                HStack {
                    Button {
                        audio.play(from: a, in: ayahs)
                    } label: {
                        Label("Play", systemImage: "play.circle")
                    }
                    .buttonStyle(.plain)
                    Button {
                        wordsKey = a.key
                    } label: {
                        Label("Words", systemImage: "textformat.abc")
                    }
                    .buttonStyle(.plain)
                    Button {
                        notes.add(title: "Ayah \(a.key)", body: "\(ar)\n\n\(a.english)\n\n\(a.urdu)", ref: a.key, linkKind: "Qur’an")
                    } label: {
                        Label("Note", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                    Button {
                        bookmarks.toggle(kind: "Qur’an", ref: a.key, title: "Ayah \(a.key)", arabic: ar, english: a.english, urdu: a.urdu)
                    } label: {
                        Label(
                            bookmarks.isBookmarked(kind: "Qur’an", ref: a.key) ? "Saved" : "Save",
                            systemImage: bookmarks.isBookmarked(kind: "Qur’an", ref: a.key) ? "bookmark.fill" : "bookmark"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BeUmmatiTheme.teal)
            }
            .padding(.vertical, 6)
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
    }
}
