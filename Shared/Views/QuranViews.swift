import SwiftUI

enum QuranReadMode: String, CaseIterable, Identifiable {
    case mushaf = "Qur’an only"
    case study = "With translation"
    var id: String { rawValue }
}

struct QuranListView: View {
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var plan: DailyPlanStore
    @State private var chapters: [QuranChapter] = []
    @State private var error: String?
    @State private var loading = true
    @State private var offlineIDs: Set<Int> = []

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Loading surahs…")
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
                    .navigationDestination(for: QuranChapter.self) { ch in
                        SurahDetailView(chapter: ch, notes: notes, bookmarks: bookmarks, plan: plan)
                    }
                }
            }
            .navigationTitle("Qur’an")
            .background(BeUmmatiTheme.parchment)
            .task { await load() }
            .refreshable { await load() }
        }
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
                            .foregroundStyle(reading.arabicColor)
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
                VStack(alignment: .leading, spacing: 10) {
                    Text(a.key)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(BeUmmatiTheme.brass)
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
                        ShareCardButton(kind: "Qur’an", ref: a.key, arabic: ar, english: a.english, urdu: a.urdu)
                        GiftReminderButton(kind: "Qur’an", ref: a.key, arabic: ar, english: a.english, urdu: a.urdu)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeUmmatiTheme.teal)
                    HStack {
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
