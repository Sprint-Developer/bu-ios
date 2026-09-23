import SwiftUI

enum SearchScope: String, CaseIterable, Identifiable {
    case both = "All"
    case quran = "Qur’an"
    case hadith = "Hadith"
    case library = "Lectures"
    case notes = "My notes"
    var id: String { rawValue }
}

/// A library chapter / lecture matched by title — local, so it resolves as you type.
struct LibraryTitleHit: Identifiable, Hashable {
    let seriesID: String
    let seriesTitle: String
    let seriesIcon: String
    let chapter: LibraryChapterMeta
    let hasAudio: Bool

    var id: String { "\(seriesID)/\(chapter.id)" }
}

enum LibraryTitleSearch {
    /// Matches every whitespace-separated term against chapter title, group, and series title.
    static func run(query: String, limit: Int = 40) -> [LibraryTitleHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= 2 else { return [] }
        let terms = q.split(separator: " ").map(String.init)

        var scored: [(score: Int, hit: LibraryTitleHit)] = []
        for series in LibraryCatalog.all {
            guard let chapters = series.chapters else { continue }
            let seriesLow = series.title.lowercased()
            for ch in chapters {
                let titleLow = ch.title.lowercased()
                let haystack = "\(titleLow) \(ch.group?.lowercased() ?? "") \(seriesLow)"
                guard terms.allSatisfy({ haystack.contains($0) }) else { continue }

                var score = 0
                if titleLow.contains(q) { score += 10 }
                if titleLow.hasPrefix(q) { score += 6 }
                if seriesLow.contains(q) { score += 3 }
                let hasAudio = LectureAudioCatalog.hasAudio(seriesID: series.id, chapterID: ch.id)
                if hasAudio { score += 1 }

                scored.append((score, LibraryTitleHit(
                    seriesID: series.id,
                    seriesTitle: series.title,
                    seriesIcon: series.icon,
                    chapter: ch,
                    hasAudio: hasAudio
                )))
            }
        }
        return scored.sorted { $0.score > $1.score }.prefix(limit).map { $0.hit }
    }
}

struct SearchView: View {
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @EnvironmentObject var reading: ReadingSettings
    @State private var query = ""
    @State private var quranHits: [QuranAyah] = []
    @State private var hadithHits: [HadithItem] = []
    @State private var libraryHits: [LibraryTitleHit] = []
    @State private var loading = false
    @State private var scope: SearchScope = .both
    @State private var book = "all"
    @State private var status = "Search Qur’an, Hadith, lectures, and your notes."
    @State private var searched = false

    private var showsLibrary: Bool { scope == .both || scope == .library }

    private var noteHits: [NoteItem] {
        guard scope == .both || scope == .notes else { return [] }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        return notes.filtered(query: q, tag: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        TextField("Search…", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await run() } }
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(BeUmmatiTheme.teal.opacity(0.12), lineWidth: 1))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SearchScope.allCases) { s in
                                BeUmmatiChip(title: s.rawValue, selected: scope == s) {
                                    scope = s
                                    if searched { Task { await run() } }
                                }
                            }
                        }
                    }

                    // Library titles are on-device: show them while Qur’an / Hadith fetch.
                    if showsLibrary, !libraryHits.isEmpty {
                        libraryResults
                    }

                    if loading {
                        ProgressView("Searching…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if searched {
                        results
                    } else if libraryHits.isEmpty {
                        Text(status)
                            .font(BeUmmatiTheme.ui(14))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            .padding(.top, 12)
                    }
                }
                .padding(20)
            }
            .beUmmatiScreenBackground()
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Go") { Task { await run() } }
                        .fontWeight(.semibold)
                        .disabled(loading)
                }
            }
            .task(id: query) {
                // Debounce so a fast typist doesn't rescan the catalog on every keystroke.
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                libraryHits = LibraryTitleSearch.run(query: query)
            }
        }
    }

    @ViewBuilder
    private var libraryResults: some View {
        sectionHeader("Lectures & chapters · \(libraryHits.count)")
        ForEach(libraryHits) { hit in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: hit.seriesIcon)
                        .foregroundStyle(BeUmmatiTheme.teal)
                    Text(hit.seriesTitle)
                        .font(BeUmmatiTheme.ui(12, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let vol = hit.chapter.volume {
                        Text("Vol \(vol)")
                            .font(BeUmmatiTheme.ui(11, weight: .bold))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    }
                }
                Text(highlighted(hit.chapter.title, term: query))
                    .font(BeUmmatiTheme.heading(16))
                    .foregroundStyle(BeUmmatiTheme.ink)
                if let group = hit.chapter.group, !group.isEmpty {
                    Text(group)
                        .font(BeUmmatiTheme.ui(12))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                }
                HStack(spacing: 14) {
                    if let series = LibraryCatalog.series(id: hit.seriesID) {
                        NavigationLink {
                            LibraryChapterReaderView(series: series, chapter: hit.chapter)
                        } label: {
                            Label("Read", systemImage: "book")
                        }
                        .buttonStyle(.plain)

                        if hit.hasAudio {
                            Button {
                                playLecture(series: series, chapter: hit.chapter)
                            } label: {
                                Label("Listen", systemImage: "play.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer()
                }
                .font(BeUmmatiTheme.ui(13, weight: .semibold))
                .foregroundStyle(BeUmmatiTheme.teal)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .beUmmatiCard()
        }
    }

    private func playLecture(series: LibrarySeries, chapter: LibraryChapterMeta) {
        guard let track = LectureAudioCatalog.track(seriesID: series.id, chapterID: chapter.id) else { return }
        LectureAudioSession.shared.play(series: series, chapter: chapter, track: track)
        LectureAudioSession.shared.showFullPlayer = true
    }

    @ViewBuilder
    private var results: some View {
        if scope == .both || scope == .quran {
            sectionHeader("Qur’an · \(quranHits.count)")
            ForEach(quranHits) { a in
                let ar = a.arabic(for: reading.arabicFont)
                resultCard(
                    title: "Ayah \(a.key)",
                    kind: "Qur’an",
                    ref: a.key,
                    arabic: ar,
                    english: a.english,
                    urdu: a.urdu
                )
            }
        }
        if scope == .both || scope == .hadith {
            sectionHeader("Hadith · \(hadithHits.count)")
            ForEach(hadithHits) { h in
                let bookName = HadithAPI.books.first { $0.slug == h.book }?.name ?? h.book
                resultCard(
                    title: "\(bookName) #\(h.number)",
                    kind: "Hadith",
                    ref: "\(bookName) #\(h.number)",
                    arabic: h.arabic,
                    english: h.english,
                    urdu: h.urdu
                )
            }
        }
        if scope == .both || scope == .notes {
            sectionHeader("My notes · \(noteHits.count)")
            ForEach(noteHits) { n in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your note · \(n.ref)")
                        .font(BeUmmatiTheme.ui(12, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                    Text(highlighted(n.body, term: query))
                        .font(BeUmmatiTheme.ui(15))
                        .foregroundStyle(BeUmmatiTheme.ink)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .beUmmatiCard()
            }
        }
        if quranHits.isEmpty && hadithHits.isEmpty && noteHits.isEmpty && libraryHits.isEmpty {
            Text(status)
                .font(BeUmmatiTheme.ui(14))
                .foregroundStyle(BeUmmatiTheme.inkSecondary)
        }
    }

    private func sectionHeader(_ t: String) -> some View {
        Text(t)
            .font(BeUmmatiTheme.heading(16))
            .foregroundStyle(BeUmmatiTheme.ink)
            .padding(.top, 8)
    }

    private func resultCard(title: String, kind: String, ref: String, arabic: String, english: String, urdu: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(ref)
                .font(BeUmmatiTheme.ui(12, weight: .bold))
                .foregroundStyle(BeUmmatiTheme.brass)
            if reading.showEnglish, !english.isEmpty {
                Text(highlighted(english, term: query))
                    .font(BeUmmatiTheme.ui(15))
                    .foregroundStyle(BeUmmatiTheme.ink)
            }
            if reading.showArabic, !arabic.isEmpty {
                Text(arabic)
                    .font(reading.arabicFont.font(size: reading.arabicSize * 0.85))
                    .foregroundStyle(BeUmmatiTheme.ink)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .leftToRight)
            }
            HStack {
                BeUmmatiShareButton(title: title, kind: kind, ref: ref, arabic: arabic, english: english, urdu: urdu)
                Button {
                    bookmarks.toggle(kind: kind, ref: ref, title: title, arabic: arabic, english: english, urdu: urdu)
                } label: {
                    Label(bookmarks.isBookmarked(kind: kind, ref: ref) ? "Saved" : "Save", systemImage: "bookmark")
                }
                .buttonStyle(.plain)
            }
            .font(BeUmmatiTheme.ui(13, weight: .semibold))
            .foregroundStyle(BeUmmatiTheme.teal)
        }
        .padding(16)
        .beUmmatiCard()
    }

    private func highlighted(_ text: String, term: String) -> AttributedString {
        var attr = AttributedString(text)
        let q = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return attr }
        let lower = text.lowercased()
        let needle = q.lowercased()
        var searchStart = lower.startIndex
        while let range = lower.range(of: needle, range: searchStart..<lower.endIndex) {
            if let aStart = AttributedString.Index(range.lowerBound, within: attr),
               let aEnd = AttributedString.Index(range.upperBound, within: attr) {
                attr[aStart..<aEnd].foregroundColor = UIColor(BeUmmatiTheme.brass)
                attr[aStart..<aEnd].font = .system(size: 15, weight: .semibold)
            }
            searchStart = range.upperBound
        }
        return attr
    }

    private func run() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            status = "Type at least 2 characters."
            return
        }
        libraryHits = LibraryTitleSearch.run(query: q)
        if scope == .notes {
            searched = true
            loading = false
            status = noteHits.isEmpty ? "No notes matched." : ""
            return
        }
        if scope == .library {
            searched = true
            loading = false
            status = libraryHits.isEmpty ? "No lecture or chapter title matched." : ""
            return
        }
        loading = true
        searched = true
        defer { loading = false }
        quranHits = []
        hadithHits = []
        do {
            switch scope {
            case .both:
                async let qRes = QuranAPI.shared.search(query: q)
                async let hRes = HadithAPI.shared.search(query: q, book: nil, maxSections: 12)
                quranHits = try await qRes
                hadithHits = try await hRes
            case .quran:
                quranHits = try await QuranAPI.shared.search(query: q)
            case .hadith:
                hadithHits = try await HadithAPI.shared.search(query: q, book: book == "all" ? nil : book, maxSections: 20)
            case .library, .notes:
                break
            }
            if quranHits.isEmpty && hadithHits.isEmpty && noteHits.isEmpty && libraryHits.isEmpty {
                status = "No matches for “\(q)”."
            } else {
                status = ""
            }
        } catch {
            status = error.localizedDescription
        }
    }
}

struct NotesView: View {
    @ObservedObject var notes: NotesStore
    @EnvironmentObject var reading: ReadingSettings
    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var draftTags = ""
    @State private var query = ""
    @State private var tagFilter: String?

    var body: some View {
        List {
            Section("Find") {
                TextField("Search notes…", text: $query)
                    .textInputAutocapitalization(.never)
                if !notes.allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            BeUmmatiChip(title: "All", selected: tagFilter == nil) { tagFilter = nil }
                            ForEach(notes.allTags, id: \.self) { tag in
                                BeUmmatiChip(title: tag, selected: tagFilter == tag) {
                                    tagFilter = tagFilter == tag ? nil : tag
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            Section("New note") {
                TextField("Title", text: $draftTitle)
                TextField("Tags (comma separated)", text: $draftTags)
                    .textInputAutocapitalization(.never)
                TextField("Write in Arabic, English, or Urdu…", text: $draftBody, axis: .vertical)
                    .lineLimit(3...8)
                Button("Save note") {
                    guard !draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    let tags = draftTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    notes.add(title: draftTitle.isEmpty ? "Note" : draftTitle, body: draftBody, ref: "personal", tags: tags, linkKind: "personal")
                    draftTitle = ""; draftBody = ""; draftTags = ""
                }
            }
            Section("Saved · \(notes.filtered(query: query, tag: tagFilter).count)") {
                let list = notes.filtered(query: query, tag: tagFilter)
                if list.isEmpty {
                    Text("Notes from ayahs, hadith, or your own writing appear here.")
                        .foregroundStyle(.secondary)
                }
                ForEach(list) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(n.title).font(BeUmmatiTheme.heading(16))
                            Spacer()
                            Text(relativeDate(n.created))
                                .font(BeUmmatiTheme.ui(11))
                                .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        }
                        Text(n.body).font(BeUmmatiTheme.ui(14)).lineLimit(6)
                        if !n.tags.isEmpty {
                            Text(n.tags.map { "#\($0)" }.joined(separator: " "))
                                .font(BeUmmatiTheme.ui(12, weight: .medium))
                                .foregroundStyle(BeUmmatiTheme.teal)
                        }
                        HStack {
                            Text(n.ref).font(.caption).foregroundStyle(.secondary)
                            if !n.linkKind.isEmpty {
                                Text(n.linkKind)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BeUmmatiTheme.brass)
                            }
                            Spacer()
                            ShareLink(item: "\(n.title)\n\(n.ref)\n\n\(n.body)\n\n— Be Ummati") {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { notes.delete(n) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
        .navigationTitle("Notes")
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
