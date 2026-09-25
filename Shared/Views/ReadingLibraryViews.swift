import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ReadingLibraryView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Urdu tafsir (bundled offline), history, Sahaba stories, and the Seerah series. Long chapters load from the app bundle first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Library") {
                    NavigationLink {
                        DuasLibraryView()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "hands.sparkles.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(BeUmmatiTheme.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Duas & Adhkar")
                                    .font(BeUmmatiTheme.heading(17))
                                Text("Hisn al-Muslim · \(HisnAlMuslim.allDuas.count) authentic with references")
                                    .font(BeUmmatiTheme.ui(12))
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    ForEach(LibraryCatalog.all.filter { !$0.id.hasPrefix("anwar-") }) { series in
                        NavigationLink {
                            libraryDestination(series)
                        } label: {
                            libraryRow(series)
                        }
                    }
                }
                Section("Imam Anwar al-Awlaki") {
					Text("Full Al Qalam catalog — Seerah (53), Prophets, Hereafter, Abu Bakr, Umar, BOJ & more. Transcripts from SRT · YouTube where available · https://alqalamhistory.com/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(LibraryCatalog.all.filter { $0.id.hasPrefix("anwar-") }) { series in
                        NavigationLink {
                            libraryDestination(series)
                        } label: {
                            libraryRow(series)
                        }
                    }
                }
                Section {
                    NavigationLink {
                        ScholarsLibraryView()
                    } label: {
                        Label("Scholar sayings", systemImage: "quote.bubble")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BeUmmatiTheme.parchment)
            .navigationTitle("Library")
        }
    }

    @ViewBuilder
    private func libraryDestination(_ series: LibrarySeries) -> some View {
        switch series.kind {
        case .quranTafsir:
            TafsirIbnKathirUrduView()
        case .sahaba:
            SahabaStoriesView()
        case .chapters:
            LibrarySeriesChaptersView(series: series)
        }
    }

    private func libraryRow(_ series: LibrarySeries) -> some View {
        let progress = LibraryProgressStore.shared
        let total = series.chapterCount
        let n = total > 0 ? progress.progressCount(seriesID: series.id, total: total) : 0
        return HStack(spacing: 14) {
            Image(systemName: series.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(BeUmmatiTheme.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(series.title)
                    .font(BeUmmatiTheme.heading(17))
                Text(series.subtitle)
                    .font(BeUmmatiTheme.ui(12))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    .lineLimit(2)
                if series.id.hasPrefix("anwar-"), total > 0 {
                    HStack(spacing: 8) {
                        Text("\(n)/\(total) lectures")
                            .font(BeUmmatiTheme.ui(11, weight: .semibold))
                            .foregroundStyle(BeUmmatiTheme.brass)
                        let urduN = (series.chapters ?? []).filter {
                            guard let u = $0.srtUrdu, !u.isEmpty else { return false }
                            return SRTCueParser.bundleContainsSRT(u)
                        }.count
                        if urduN > 0 {
                            Text("اردو · \(urduN)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(BeUmmatiTheme.teal.opacity(0.12), in: Capsule())
                                .foregroundStyle(BeUmmatiTheme.teal)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tafsir Ibn Kathir (Urdu)

struct TafsirIbnKathirUrduView: View {
    @State private var chapters: [QuranChapter] = []
    @State private var loading = true
    @State private var loadError = ""

    var body: some View {
        Group {
            if loading && chapters.isEmpty {
                ProgressView("Loading surahs…")
            } else if !loadError.isEmpty && chapters.isEmpty {
                ContentUnavailableView("Could not load", systemImage: "wifi.exclamationmark", description: Text(loadError))
            } else {
                List(chapters) { ch in
                    NavigationLink {
                        TafsirSurahReaderView(chapter: ch)
                    } label: {
                        HStack {
                            Text("\(ch.id).")
                                .font(BeUmmatiTheme.ui(14, weight: .bold))
                                .foregroundStyle(BeUmmatiTheme.brass)
                                .frame(width: 36, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ch.nameArabic.isEmpty ? ch.nameSimple : ch.nameArabic)
                                    .font(BeUmmatiTheme.heading(16))
                                Text("\(ch.nameSimple) · \(ch.versesCount) ayahs")
                                    .font(BeUmmatiTheme.ui(12))
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .beUmmatiScreenBackground()
        .navigationTitle("Tafsir Ibn Kathir")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadChapters() }
    }

    private func loadChapters() async {
        loading = true
        defer { loading = false }
        do {
            chapters = try await QuranAPI.shared.chapters()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct TafsirSurahReaderView: View {
    let chapter: QuranChapter
    @EnvironmentObject var reading: ReadingSettings
    @State private var entries: [TafsirEntry] = []
    @State private var ayahs: [QuranAyah] = []
    @State private var loading = true
    @State private var loadError = ""

    var body: some View {
        Group {
            if loading && entries.isEmpty {
                ProgressView("اردو تفسير لوڈ ہو رہی ہے…")
            } else if !loadError.isEmpty && entries.isEmpty {
                ContentUnavailableView("Tafsir unavailable", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                ZoomableScrollView(minZoom: 1, maxZoom: 3) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(entries, id: \.ayah) { entry in
                            let ayahText = ayahs.first(where: { $0.key == "\(chapter.id):\(entry.ayah)" })
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(chapter.id):\(entry.ayah)")
                                    .font(BeUmmatiTheme.ui(12, weight: .bold))
                                    .foregroundStyle(BeUmmatiTheme.brass)
                                    .beUmmatiSelectableText()

                                if let ayahText {
                                    Text(ayahText.arabic(for: reading.arabicFont))
                                        .font(reading.arabicFont.font(size: reading.arabicSize))
                                        .foregroundStyle(reading.arabicColor)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .lineSpacing(reading.arabicLineSpacing)
                                        .beUmmatiSelectableText()
                                }

                                ShapedUrduBlock(
                                    text: entry.text,
                                    fontSize: max(reading.urduSize + 2, 19),
                                    postScriptName: reading.urduFont.postScriptName,
                                    textColor: UIColor(reading.urduColor)
                                )
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .beUmmatiCard()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .beUmmatiScreenBackground()
        .navigationTitle(chapter.nameSimple)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            async let t = TafsirAPI.shared.chapter(surah: chapter.id, verseCount: chapter.versesCount)
            async let a = QuranAPI.shared.ayahs(chapter: chapter.id)
            entries = try await t
            ayahs = try await a
        } catch {
            self.loadError = error.localizedDescription
        }
    }
}

// MARK: - Chapter-based series

struct LibrarySeriesChaptersView: View {
    let series: LibrarySeries
    @ObservedObject private var progress = LibraryProgressStore.shared
    @ObservedObject private var audio = LectureAudioSession.shared

    private var grouped: [(String, [LibraryChapterMeta])] {
        let chapters = series.chapters ?? []
        var order: [String] = []
        var dict: [String: [LibraryChapterMeta]] = [:]
        for ch in chapters {
            let key = ch.group ?? (ch.volume.map { "Volume \($0) · \(ch.volumeTitle ?? "")" } ?? "Chapters")
            if dict[key] == nil { order.append(key) }
            dict[key, default: []].append(ch)
        }
        return order.map { ($0, dict[$0]!) }
    }

    private var progressLabel: String {
        let total = series.chapterCount
        let n = progress.progressCount(seriesID: series.id, total: total)
        return "\(n)/\(total)"
    }

    private var urduChapterCount: Int {
        (series.chapters ?? []).filter { ch in
            guard let u = ch.srtUrdu, !u.isEmpty else { return false }
            return SRTCueParser.bundleContainsSRT(u)
        }.count
    }

    var body: some View {
        List {
            Section {
                Text(series.attribution)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Progress")
                        .font(BeUmmatiTheme.ui(14, weight: .semibold))
                    Spacer()
                    Text(progressLabel)
                        .font(BeUmmatiTheme.ui(14, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.teal)
                }
                ProgressView(
                    value: Double(progress.progressCount(seriesID: series.id, total: max(series.chapterCount, 1))),
                    total: Double(max(series.chapterCount, 1))
                )
                .tint(BeUmmatiTheme.brass)

                if urduChapterCount > 0 {
                    Label("\(urduChapterCount) lectures with Urdu SRT", systemImage: "text.bubble")
                        .font(BeUmmatiTheme.ui(13, weight: .semibold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                }

                if let next = progress.nextChapter(in: series) {
                    NavigationLink {
                        LibraryChapterReaderView(series: series, chapter: next)
                    } label: {
                        Label("Next up: \(next.title)", systemImage: "forward.fill")
                    }
                }
                if let last = progress.last(for: series.id),
                   let meta = series.chapters?.first(where: { $0.id == last }) {
                    NavigationLink {
                        LibraryChapterReaderView(series: series, chapter: meta)
                    } label: {
                        Label("Continue: \(meta.title)", systemImage: "bookmark.fill")
                    }
                }
            }
            if series.id.hasPrefix("anwar-") || series.id == "tareekh-ibn-kathir-urdu" {
                Section {
                    NavigationLink {
                        LibraryContentSettingsView(seriesID: series.id)
                    } label: {
                        Label("Import chapters", systemImage: "square.and.arrow.down")
                    }
                }
            }
            ForEach(grouped, id: \.0) { group, items in
                Section(group) {
                    ForEach(items) { ch in
                        NavigationLink {
                            LibraryChapterReaderView(series: series, chapter: ch)
                        } label: {
                            HStack(spacing: 8) {
                                if let vol = ch.volume {
                                    Text("Vol \(vol)")
                                        .font(BeUmmatiTheme.ui(11, weight: .bold))
                                        .foregroundStyle(BeUmmatiTheme.brass)
                                }
                                Text(ch.title)
                                    .font(BeUmmatiTheme.ui(15))
                                Spacer(minLength: 8)
                                if let u = ch.srtUrdu, !u.isEmpty, SRTCueParser.bundleContainsSRT(u) {
                                    Text("اردو")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(BeUmmatiTheme.brass.opacity(0.18), in: Capsule())
                                        .foregroundStyle(BeUmmatiTheme.teal)
                                }
                                if progress.isCompleted(seriesID: series.id, chapterID: ch.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(BeUmmatiTheme.teal)
                                }
                                if let track = LectureAudioCatalog.track(seriesID: series.id, chapterID: ch.id) {
                                    Image(systemName: audio.isDownloaded(track) ? "arrow.down.circle.fill" : "waveform")
                                        .font(.caption)
                                        .foregroundStyle(BeUmmatiTheme.brass)
                                }
                                if ch.youtubeId != nil {
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(BeUmmatiTheme.teal)
                                }
                            }
                        }
                        .contextMenu {
                            if let track = LectureAudioCatalog.track(seriesID: series.id, chapterID: ch.id) {
                                Button {
                                    audio.play(series: series, chapter: ch, track: track)
                                    audio.showFullPlayer = true
                                } label: {
                                    Label("Listen", systemImage: "play.fill")
                                }
                                Button {
                                    Task {
                                        if audio.isDownloaded(track) {
                                            audio.removeDownload(track)
                                        } else {
                                            await audio.download(track)
                                        }
                                    }
                                } label: {
                                    Label(
                                        audio.isDownloaded(track) ? "Remove download" : "Download for offline",
                                        systemImage: audio.isDownloaded(track) ? "trash" : "arrow.down.circle"
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LibraryChapterReaderView: View {
    let series: LibrarySeries
    let chapter: LibraryChapterMeta
    @EnvironmentObject var reading: ReadingSettings
    @EnvironmentObject var bookmarks: BookmarkStore
    @StateObject private var notes = NotesStore()
    @ObservedObject private var progress = LibraryProgressStore.shared
    @State private var bodyText: LibraryChapterBody?
    @State private var loading = true
    @State private var loadError = ""
    @State private var importChapter = false
    @State private var langTab: SeriesLangTab = .english
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var initialOffsetY: CGFloat = 0
    @ObservedObject private var audio = LectureAudioSession.shared

    private enum SeriesLangTab: String, CaseIterable, Identifiable {
        case arabic, english, urdu
        var id: String { rawValue }
        var label: String {
            switch self {
            case .arabic: return "Arabic"
            case .english: return "English"
            case .urdu: return "Urdu"
            }
        }
    }

    private var audioTrack: LectureAudioTrack? {
        LectureAudioCatalog.track(seriesID: series.id, chapterID: chapter.id)
    }

    var body: some View {
        Group {
            if loading && bodyText == nil {
                ProgressView()
            } else if let bodyText {
                VStack(spacing: 0) {
                    readerChrome(bodyText)
                    ZoomableScrollView(
                        minZoom: 1,
                        maxZoom: 3,
                        initialOffsetY: initialOffsetY,
                        onOffsetChange: { y in
                            progress.setScrollY(seriesID: series.id, chapterID: chapter.id, y: Double(y))
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            if showSearch, !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                                searchResults(bodyText)
                            } else {
                                langBody(bodyText)
                            }
                            Text("Pinch to zoom · double-tap to reset · press & hold to copy")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            actionRow(bodyText)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Chapter not installed",
                    systemImage: "tray.and.arrow.down",
                    description: Text(loadError.isEmpty ? LibraryContentError.missing.localizedDescription : loadError)
                )
                Button("Import JSON chapter") { importChapter = true }
                    .buttonStyle(.borderedProminent)
                    .tint(BeUmmatiTheme.teal)
            }
        }
        .beUmmatiScreenBackground()
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let track = audioTrack {
                    Button { startListening(track: track) } label: {
                        Image(systemName: "play.circle.fill")
                    }
                    Button {
                        Task {
                            if audio.isDownloaded(track) {
                                audio.removeDownload(track)
                            } else {
                                await audio.download(track)
                            }
                        }
                    } label: {
                        Image(systemName: audio.isDownloaded(track) ? "checkmark.circle.fill" : "arrow.down.circle")
                    }
                }
                Button {
                    withAnimation { showSearch.toggle() }
                } label: {
                    Image(systemName: showSearch ? "xmark.circle" : "magnifyingglass")
                }
            }
        }
        .fileImporter(isPresented: $importChapter, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            Task {
                do {
                    let got = url.startAccessingSecurityScopedResource()
                    defer { if got { url.stopAccessingSecurityScopedResource() } }
                    try await LibraryContentService.shared.importPackFile(from: url, seriesID: series.id, chapterID: chapter.id)
                    await reload()
                } catch {
                    self.loadError = error.localizedDescription
                }
            }
        }
        .task { await reload() }
        .onAppear {
            progress.mark(seriesID: series.id, chapterID: chapter.id)
            if let y = progress.scrollOffset(seriesID: series.id, chapterID: chapter.id) {
                initialOffsetY = CGFloat(y)
            }
        }
        .onChange(of: langTab) { _, new in
            progress.setLangTab(seriesID: series.id, chapterID: chapter.id, tab: new.rawValue)
        }
    }

    @ViewBuilder
    private func readerChrome(_ bodyText: LibraryChapterBody) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(chapter.title)
                .font(BeUmmatiTheme.heading(22))
                .beUmmatiSelectableText()
            if !bodyText.reference.isEmpty {
                Text(bodyText.reference)
                    .font(BeUmmatiTheme.ui(12, weight: .semibold))
                    .foregroundStyle(BeUmmatiTheme.brass)
                    .beUmmatiSelectableText()
            }
            HStack(spacing: 10) {
                if let track = audioTrack {
                    Button { startListening(track: track) } label: {
                        Label("Listen + subtitles", systemImage: "waveform")
                            .font(BeUmmatiTheme.ui(14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(BeUmmatiTheme.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                if let yt = bodyText.youtubeId ?? chapter.youtubeId, !yt.isEmpty,
                   let url = URL(string: "https://www.youtube.com/watch?v=\(yt)") {
                    Link(destination: url) {
                        Label("YouTube", systemImage: "play.rectangle.fill")
                            .font(BeUmmatiTheme.ui(14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(BeUmmatiTheme.brass.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(BeUmmatiTheme.teal)
                    }
                }
            }
            if showSearch {
                TextField("Search in this lecture…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            let tabs = availableTabs(bodyText)
            if tabs.count > 1 {
                Picker("Language", selection: $langTab) {
                    ForEach(tabs) { tab in
                        Text(tab.label).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func searchResults(_ bodyText: LibraryChapterBody) -> some View {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source: String = {
            switch langTab {
            case .arabic: return bodyText.arabic ?? ""
            case .urdu: return bodyText.urdu
            case .english: return bodyText.english
            }
        }()
        let paras = source
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.localizedCaseInsensitiveContains(q) }
        if paras.isEmpty {
            Text("No matches for “\(q)”")
                .font(BeUmmatiTheme.ui(14))
                .foregroundStyle(BeUmmatiTheme.inkSecondary)
        } else {
            Text("\(paras.count) match\(paras.count == 1 ? "" : "es")")
                .font(BeUmmatiTheme.ui(12, weight: .bold))
                .foregroundStyle(BeUmmatiTheme.brass)
            ForEach(Array(paras.prefix(40).enumerated()), id: \.offset) { _, para in
                Text(para)
                    .font(BeUmmatiTheme.ui(15))
                    .foregroundStyle(BeUmmatiTheme.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: langTab == .english ? .leading : .trailing)
                    .background(BeUmmatiTheme.tealSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .beUmmatiSelectableText()
                    .environment(\.layoutDirection, langTab == .english ? .leftToRight : .rightToLeft)
            }
        }
    }

    @ViewBuilder
    private func langBody(_ bodyText: LibraryChapterBody) -> some View {
        switch langTab {
        case .arabic:
            if let arabic = bodyText.arabic, !arabic.isEmpty {
                ShapedArabicText(
                    text: arabic,
                    fontSize: reading.englishSize + 4,
                    postScriptName: reading.arabicFont.postScriptName,
                    textColor: UIColor(reading.arabicColor)
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        case .urdu:
            if !bodyText.urdu.isEmpty {
                ShapedUrduBlock(
                    text: bodyText.urdu,
                    fontSize: max(reading.urduSize + 2, reading.englishSize + 2),
                    postScriptName: reading.urduFont.postScriptName,
                    textColor: UIColor(reading.urduColor)
                )
            }
        case .english:
            if !bodyText.english.isEmpty {
                MixedScriptProseText(
                    text: bodyText.english,
                    englishSize: reading.englishSize + 2,
                    arabicSize: reading.englishSize + 3,
                    arabicPostScriptName: reading.arabicFont.postScriptName,
                    englishColor: UIColor(reading.englishColor),
                    arabicColor: UIColor(reading.englishColor)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func actionRow(_ bodyText: LibraryChapterBody) -> some View {
        let shareAr = langTab == .arabic ? (bodyText.arabic ?? "") : ""
        let shareEn = langTab == .english ? bodyText.english : ""
        let shareUr = langTab == .urdu ? bodyText.urdu : ""
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                BeUmmatiShareButton(
                    title: chapter.title,
                    kind: series.title,
                    ref: chapter.id,
                    arabic: shareAr,
                    english: shareEn,
                    urdu: shareUr
                )
                Button {
                    notes.add(
                        title: chapter.title,
                        body: shareEn.isEmpty ? (shareUr.isEmpty ? shareAr : shareUr) : shareEn,
                        ref: "\(series.title) · \(chapter.id)",
                        linkKind: series.title
                    )
                } label: {
                    Label("Note", systemImage: "square.and.pencil")
                }
                .buttonStyle(.plain)
            }
            .font(BeUmmatiTheme.ui(13, weight: .semibold))
            .foregroundStyle(BeUmmatiTheme.teal)

            Button {
                progress.markCompleted(seriesID: series.id, chapterID: chapter.id)
            } label: {
                Label(
                    progress.isCompleted(seriesID: series.id, chapterID: chapter.id)
                        ? "Marked complete"
                        : "Mark lecture complete",
                    systemImage: progress.isCompleted(seriesID: series.id, chapterID: chapter.id)
                        ? "checkmark.circle.fill"
                        : "checkmark.circle"
                )
                .font(BeUmmatiTheme.ui(14, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(BeUmmatiTheme.brass)
        }
    }

    private func availableTabs(_ body: LibraryChapterBody) -> [SeriesLangTab] {
        var tabs: [SeriesLangTab] = []
        if let ar = body.arabic, !ar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tabs.append(.arabic)
        }
        if !body.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tabs.append(.english)
        }
        if !body.urdu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tabs.append(.urdu)
        }
        return tabs
    }

    private func pickDefaultTab(_ body: LibraryChapterBody) {
        let tabs = availableTabs(body)
        guard !tabs.isEmpty else { return }
        if let saved = progress.langTab(seriesID: series.id, chapterID: chapter.id),
           let tab = SeriesLangTab(rawValue: saved), tabs.contains(tab) {
            langTab = tab
        } else if tabs.contains(.english) {
            langTab = .english
        } else {
            langTab = tabs[0]
        }
    }

    private func startListening(track: LectureAudioTrack) {
        let fallback: String = {
            guard let bodyText else { return "" }
            if !bodyText.english.isEmpty { return bodyText.english }
            if !bodyText.urdu.isEmpty { return bodyText.urdu }
            return bodyText.arabic ?? ""
        }()
        let lang: SubtitleLang = {
            switch langTab {
            case .urdu: return .urdu
            case .arabic: return .arabic
            case .english: return .english
            }
        }()
        audio.play(
            series: series,
            chapter: chapter,
            track: track,
            lang: lang,
            fallbackTranscript: fallback
        )
        audio.showFullPlayer = true
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        do {
            let loaded = try await LibraryContentService.shared.loadChapter(seriesID: series.id, chapterID: chapter.id)
            bodyText = loaded
            pickDefaultTab(loaded)
            loadError = ""
        } catch {
            bodyText = nil
            loadError = error.localizedDescription
        }
    }
}

struct LibraryContentSettingsView: View {
    let seriesID: String
    @AppStorage("beummati.library.remoteBase") private var remoteBase = ""
    @State private var saved = false

    var body: some View {
        Form {
            Section {
                Text("Optional HTTPS base where each chapter is `{base}/{series}/{chapterId}.json`. Use this to host the full Urdu Tareekh or transcribed Seerah text you have rights to.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Content server") {
                TextField("https://your-cdn.example/library", text: $remoteBase)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
            }
            Section("Format") {
                Text("Each file: `{ \"title\": \"…\", \"urdu\": \"…\", \"english\": \"…\", \"reference\": \"…\" }`")
                    .font(.caption.monospaced())
            }
            Section {
                Button("Save") {
                    saved = true
                }
            }
        }
        .navigationTitle("Import & sync")
        .alert("Saved", isPresented: $saved) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - Sahaba

struct SahabaStoriesView: View {
    @State private var query = ""
    @EnvironmentObject var reading: ReadingSettings
    @EnvironmentObject var bookmarks: BookmarkStore
    @StateObject private var notes = NotesStore()

    private var stories: [SahabaStory] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let list = SahabaLibrary.stories
        guard !q.isEmpty else { return list }
        return list.filter {
            $0.name.lowercased().contains(q)
                || $0.title.lowercased().contains(q)
                || $0.theme.lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            Section {
                Text("\(SahabaLibrary.stories.count) companion stories with classical references only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(stories) { story in
                NavigationLink {
                    SahabaStoryDetailView(story: story)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(story.name)
                            .font(BeUmmatiTheme.heading(17))
                        Text(story.title)
                            .font(BeUmmatiTheme.ui(13))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
        .navigationTitle("Stories of the Sahaba")
        .searchable(text: $query, prompt: "Search companions")
    }
}

struct SahabaStoryDetailView: View {
    let story: SahabaStory
    @EnvironmentObject var reading: ReadingSettings
    @StateObject private var notes = NotesStore()

    var body: some View {
        ZoomableScrollView(minZoom: 1, maxZoom: 3) {
            VStack(alignment: .leading, spacing: 14) {
                Text(story.name)
                    .font(BeUmmatiTheme.heading(26))
                    .beUmmatiSelectableText()
                Text(story.title)
                    .font(BeUmmatiTheme.ui(14, weight: .semibold))
                    .foregroundStyle(BeUmmatiTheme.brass)
                    .beUmmatiSelectableText()
                Text(story.reference)
                    .font(BeUmmatiTheme.ui(12))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    .beUmmatiSelectableText()
                if !story.urdu.isEmpty {
                    ShapedUrduBlock(
                        text: story.urdu,
                        fontSize: max(reading.urduSize + 2, reading.englishSize + 2),
                        postScriptName: reading.urduFont.postScriptName,
                        textColor: UIColor(reading.urduColor)
                    )
                }
                MixedScriptProseText(
                    text: story.english,
                    englishSize: reading.englishSize + 2,
                    arabicSize: reading.englishSize + 3,
                    arabicPostScriptName: reading.arabicFont.postScriptName,
                    englishColor: UIColor(reading.englishColor),
                    arabicColor: UIColor(reading.englishColor)
                )
                Text("Pinch to zoom · double-tap to reset · press & hold to copy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack {
                    BeUmmatiShareButton(title: story.title, kind: "Sahaba", ref: story.name, arabic: "", english: story.english, urdu: story.urdu)
                    Button {
                        notes.add(title: "\(story.name) — \(story.title)", body: story.english, ref: story.reference, linkKind: "Sahaba")
                    } label: {
                        Label("Note", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                }
                .font(BeUmmatiTheme.ui(13, weight: .semibold))
                .foregroundStyle(BeUmmatiTheme.teal)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .beUmmatiScreenBackground()
        .navigationTitle(story.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
