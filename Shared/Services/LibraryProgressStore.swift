import Foundation
import Combine

/// Progress, resume offsets, and completed chapters for Library series.
@MainActor
final class LibraryProgressStore: ObservableObject {
    static let shared = LibraryProgressStore()

    @Published private(set) var lastChapter: [String: String] = [:]
    /// seriesID → set of completed chapter IDs
    @Published private(set) var completed: [String: Set<String>] = [:]
    /// "seriesID/chapterID" → language tab raw value
    @Published private(set) var langTab: [String: String] = [:]
    /// Scroll offsets — not @Published (updating these must not redraw the reader).
    private var scrollY: [String: Double] = [:]
    private var scrollPersistWork: DispatchWorkItem?

    private let key = "beummati.library.progress.v2"

    struct Snapshot: Codable {
        var lastChapter: [String: String]
        var completed: [String: [String]]
        var langTab: [String: String]
        var scrollY: [String: Double]
    }

    init() {
        AppIdentity.migrateStorageIfNeeded()
        // Migrate v1
        if let data = UserDefaults.standard.data(forKey: "beummati.library.progress"),
           let map = try? JSONDecoder().decode([String: String].self, from: data),
           UserDefaults.standard.data(forKey: key) == nil {
            lastChapter = map
            persist()
        }
        if let data = UserDefaults.standard.data(forKey: key),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            lastChapter = snap.lastChapter
            completed = snap.completed.mapValues { Set($0) }
            langTab = snap.langTab
            scrollY = snap.scrollY
        }
    }

    private func persist() {
        let snap = Snapshot(
            lastChapter: lastChapter,
            completed: completed.mapValues { Array($0).sorted() },
            langTab: langTab,
            scrollY: scrollY
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func mark(seriesID: String, chapterID: String) {
        lastChapter[seriesID] = chapterID
        persist()
        objectWillChange.send()
    }

    func last(for seriesID: String) -> String? {
        lastChapter[seriesID]
    }

    func markCompleted(seriesID: String, chapterID: String) {
        var set = completed[seriesID] ?? []
        set.insert(chapterID)
        completed[seriesID] = set
        persist()
        objectWillChange.send()
    }

    func isCompleted(seriesID: String, chapterID: String) -> Bool {
        completed[seriesID]?.contains(chapterID) ?? false
    }

    func completedCount(seriesID: String) -> Int {
        completed[seriesID]?.count ?? 0
    }

    /// Progress including the chapter you're currently on.
    func progressCount(seriesID: String, total: Int) -> Int {
        let done = completedCount(seriesID: seriesID)
        if let last = lastChapter[seriesID], !(completed[seriesID]?.contains(last) ?? false) {
            return min(total, done + 1)
        }
        return min(total, done)
    }

    func nextChapter(in series: LibrarySeries) -> LibraryChapterMeta? {
        guard let chapters = series.chapters, !chapters.isEmpty else { return nil }
        let done = completed[series.id] ?? []
        if let last = lastChapter[series.id],
           let idx = chapters.firstIndex(where: { $0.id == last }) {
            let next = chapters.index(after: idx)
            if next < chapters.endIndex { return chapters[next] }
        }
        return chapters.first { !done.contains($0.id) }
    }

    func setLangTab(seriesID: String, chapterID: String, tab: String) {
        langTab["\(seriesID)/\(chapterID)"] = tab
        persist()
    }

    func langTab(seriesID: String, chapterID: String) -> String? {
        langTab["\(seriesID)/\(chapterID)"]
    }

    func setScrollY(seriesID: String, chapterID: String, y: Double) {
        scrollY["\(seriesID)/\(chapterID)"] = y
        // Debounce disk writes; never publish — scroll must stay smooth.
        scrollPersistWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.persist() }
        }
        scrollPersistWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func scrollOffset(seriesID: String, chapterID: String) -> Double? {
        scrollY["\(seriesID)/\(chapterID)"]
    }

    /// Best series to surface on Home (most recently touched with remaining chapters).
    func primarySeries() -> LibrarySeries? {
        let anwar = LibraryCatalog.all.filter { $0.id.hasPrefix("anwar-") }
        // Prefer series with a lastChapter
        let touched = anwar.filter { lastChapter[$0.id] != nil }
        if let s = touched.max(by: { a, b in
            progressCount(seriesID: a.id, total: a.chapterCount)
                < progressCount(seriesID: b.id, total: b.chapterCount)
        }) {
            return s
        }
        return anwar.first
    }
}
