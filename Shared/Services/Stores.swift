import Foundation
import Combine

@MainActor
final class ReminderStore: ObservableObject {
    @Published var current: ReminderItem?
    @Published var quran: ReminderItem?
    @Published var hadith: ReminderItem?
    @Published var series: ReminderItem?
    @Published var quotes: ReminderItem?
    @Published var dhikr: ReminderItem?
    @Published var loading = false
    @Published var loadingLanes: Set<ReminderLane> = []
    @Published var theme = "All"

    private var token = 0
    private var recent: [String] = []
    private var recentByLane: [ReminderLane: [String]] = [:]

    func item(for lane: ReminderLane) -> ReminderItem? {
        switch lane {
        case .quran: return quran
        case .hadith: return hadith
        case .series: return series
        case .quotes: return quotes
        case .dhikr: return dhikr
        }
    }

    /// Refresh all home lanes (and keep `current` in sync for widgets / legacy UI).
    func refresh(force: Bool = true) {
        for lane in ReminderLane.allCases {
            refresh(lane: lane, force: force)
        }
    }

    func refresh(lane: ReminderLane, force: Bool = true) {
        if !force, item(for: lane) != nil { return }
        token += 1
        let my = token
        loadingLanes.insert(lane)
        loading = true
        Task {
            defer {
                if my == token || loadingLanes.contains(lane) {
                    loadingLanes.remove(lane)
                    loading = !loadingLanes.isEmpty
                }
            }

            if lane == .series {
                await refreshSeries()
                return
            }

            var seen = recentByLane[lane] ?? []
            let pool = ReminderCatalog.smartPool(lane: lane)
            for seed in pool.prefix(24) {
                if let item = await load(seed), !seen.contains(item.ref) {
                    set(item, lane: lane)
                    remember(item.ref, lane: lane, seen: &seen)
                    if lane == .quran {
                        current = item
                        WidgetSnapshot.writeReminder(item)
                    }
                    if lane == .series {
                        WidgetSnapshot.writeSeriesReminder(item)
                    }
                    return
                }
            }
            if item(for: lane) == nil, let fallback = fallback(for: lane) {
                set(fallback, lane: lane)
                if lane == .quran {
                    current = fallback
                    WidgetSnapshot.writeReminder(fallback)
                }
                if lane == .series {
                    WidgetSnapshot.writeSeriesReminder(fallback)
                }
            }
        }
    }

    private func refreshSeries() async {
        var seen = recentByLane[.series] ?? []
        if let item = await SeriesReminderBrain.pick(avoiding: seen) {
            set(item, lane: .series)
            let key = "\(item.librarySeriesID ?? "")/\(item.libraryChapterID ?? "")"
            remember(key.isEmpty ? item.ref : key, lane: .series, seen: &seen)
            WidgetSnapshot.writeSeriesReminder(item)
            return
        }
        if series == nil, let fallback = fallback(for: .series) {
            set(fallback, lane: .series)
            WidgetSnapshot.writeSeriesReminder(fallback)
        }
    }

    private func remember(_ key: String, lane: ReminderLane, seen: inout [String]) {
        seen.append(key)
        if seen.count > 24 { seen.removeFirst(seen.count - 24) }
        recentByLane[lane] = seen
        recent.append(key)
        if recent.count > 50 { recent.removeFirst(recent.count - 50) }
    }

    private func set(_ item: ReminderItem, lane: ReminderLane) {
        switch lane {
        case .quran: quran = item
        case .hadith: hadith = item
        case .series: series = item
        case .quotes: quotes = item
        case .dhikr: dhikr = item
        }
    }

    private func fallback(for lane: ReminderLane) -> ReminderItem? {
        switch lane {
        case .quran:
            return ReminderItem(
                kind: "Qur’an",
                arabic: "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا",
                english: "So truly where there is hardship there is also ease.",
                urdu: "پس یقیناً مشکل کے ساتھ آسانی ہے۔",
                ref: "94:5",
                theme: "Patience",
                title: "With hardship, ease",
                quranKey: "94:5"
            )
        case .hadith:
            return ReminderItem(
                kind: "Hadith",
                arabic: "إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ",
                english: "Actions are but by intentions.",
                urdu: "اعمال کا دارومدار نیتوں پر ہے۔",
                ref: "Nawawi #1",
                theme: "Heart",
                title: "Actions by intention",
                hadithBook: "nawawi",
                hadithNumber: 1
            )
        case .series:
            return ReminderItem(
                kind: "Series",
                arabic: "",
                english: "Open Library to explore Seerah, the lives of the prophets, and the stories of the Sahaba — then come back for a fresh reminder from those series.",
                urdu: "",
                ref: "Library",
                theme: "Heart",
                title: "From your lecture library"
            )
        case .quotes:
            return ScholarQuotes.all.first.map { ScholarQuotes.asReminder($0) }
        case .dhikr:
            guard let d = HisnAlMuslim.allDuas.first else { return nil }
            return ReminderItem(
                kind: "Dhikr",
                arabic: d.arabic,
                english: d.english,
                urdu: "",
                ref: d.reference,
                theme: "Dhikr",
                title: HisnAlMuslim.category(id: d.categoryId)?.titleEn ?? "Dhikr",
                duaID: d.id
            )
        }
    }

    private func load(_ seed: ReminderSeed) async -> ReminderItem? {
        switch seed.kind {
        case .quran(let key):
            guard let a = try? await QuranAPI.shared.verse(key: key) else { return nil }
            let font = ScriptFont(rawValue: UserDefaults.standard.string(forKey: "beummati.readingSettings.v1.arFont") ?? "") ?? .indoPak
            return ReminderItem(
                kind: "Qur’an",
                arabic: a.arabic(for: font),
                english: a.english,
                urdu: a.urdu,
                ref: a.key,
                theme: seed.theme,
                title: seed.title,
                quranKey: a.key
            )
        case .hadith(let book, let section, let number):
            guard let h = try? await HadithAPI.shared.hadith(book: book, section: section, number: number) else { return nil }
            let bookName = HadithAPI.books.first { $0.slug == book }?.name ?? book
            return ReminderItem(
                kind: "Hadith",
                arabic: h.arabic,
                english: h.english,
                urdu: h.urdu,
                ref: "\(bookName) #\(h.number)",
                theme: seed.theme,
                title: seed.title,
                hadithBook: book,
                hadithNumber: h.number
            )
        case .scholar(let id):
            guard let q = ScholarQuotes.all.first(where: { $0.id == id }),
                  !q.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return ScholarQuotes.asReminder(q)
        case .dhikr(let id):
            guard let d = HisnAlMuslim.allDuas.first(where: { $0.id == id }) else { return nil }
            return ReminderItem(
                kind: "Dhikr",
                arabic: d.arabic,
                english: d.english,
                urdu: "",
                ref: d.reference,
                theme: seed.theme,
                title: seed.title,
                duaID: d.id
            )
        }
    }
}

@MainActor
final class NotesStore: ObservableObject {
    @Published var notes: [NoteItem] = []
    private let key = "beummati.notes.v2"
    private let legacyKey = "beummati.notes"
    private let ancientKey = "nur.notes"

    init() {
        AppIdentity.migrateStorageIfNeeded()
        load()
    }

    func add(title: String, body: String, ref: String, tags: [String] = [], linkKind: String = "") {
        let kind = linkKind.isEmpty ? Self.inferKind(ref: ref) : linkKind
        notes.insert(NoteItem(title: title, body: body, ref: ref, tags: tags, linkKind: kind), at: 0)
        save()
    }

    func update(_ note: NoteItem) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[i] = note
        save()
    }

    func delete(_ note: NoteItem) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    func filtered(query: String, tag: String?) -> [NoteItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return notes.filter { n in
            if let tag, !tag.isEmpty, !n.tags.map({ $0.lowercased() }).contains(tag.lowercased()) {
                return false
            }
            if q.isEmpty { return true }
            let hay = (n.title + " " + n.body + " " + n.ref + " " + n.tags.joined(separator: " ")).lowercased()
            return hay.contains(q)
        }
    }

    var allTags: [String] {
        Array(Set(notes.flatMap(\.tags))).sorted()
    }

    private static func inferKind(ref: String) -> String {
        if ref.contains(":") && ref.split(separator: ":").count == 2, Int(ref.split(separator: ":")[0]) != nil {
            return "Qur’an"
        }
        if ref.contains("#") || ref.contains("bukhari") || ref.contains("muslim") {
            return "Hadith"
        }
        if ref == "personal" { return "personal" }
        return ""
    }

    private func load() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: key),
           let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) {
            notes = decoded
            return
        }
        // Migrate v1 notes (no tags) — beummati + pre-rename nur
        let v1 = d.data(forKey: legacyKey) ?? d.data(forKey: ancientKey)
        if let data = v1,
           let legacy = try? JSONDecoder().decode([LegacyNote].self, from: data) {
            notes = legacy.map {
                NoteItem(id: $0.id, title: $0.title, body: $0.body, ref: $0.ref, tags: [], linkKind: Self.inferKind(ref: $0.ref), created: $0.created)
            }
            save()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private struct LegacyNote: Codable {
        var id: UUID
        var title: String
        var body: String
        var ref: String
        var created: Date
    }
}

@MainActor
final class BookmarkStore: ObservableObject {
    @Published var items: [BookmarkItem] = []
    private let key = "beummati.bookmarks.v1"

    init() { load() }

    func isBookmarked(kind: String, ref: String) -> Bool {
        items.contains { $0.kind == kind && $0.ref == ref }
    }

    func toggle(kind: String, ref: String, title: String, arabic: String, english: String, urdu: String) {
        if let i = items.firstIndex(where: { $0.kind == kind && $0.ref == ref }) {
            items.remove(at: i)
        } else {
            items.insert(
                BookmarkItem(kind: kind, ref: ref, title: title, arabic: arabic, english: english, urdu: urdu),
                at: 0
            )
        }
        save()
    }

    func remove(_ item: BookmarkItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BookmarkItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

@MainActor
final class DailyPlanStore: ObservableObject {
    @Published var goalAyahs: Int = 5
    @Published var doneAyahs: Int = 0
    @Published var reminderDone: Bool = false
    @Published var dayKey: String = ""

    private let key = "beummati.dailyPlan.v1"

    init() { rollIfNeeded() }

    func rollIfNeeded() {
        let today = Self.todayKey()
        let d = UserDefaults.standard
        if d.string(forKey: key + ".day") != today {
            d.set(today, forKey: key + ".day")
            d.set(0, forKey: key + ".done")
            d.set(false, forKey: key + ".reminder")
            dayKey = today
            doneAyahs = 0
            reminderDone = false
        } else {
            dayKey = today
            doneAyahs = d.integer(forKey: key + ".done")
            reminderDone = d.bool(forKey: key + ".reminder")
        }
        let g = d.integer(forKey: key + ".goal")
        goalAyahs = g == 0 ? 5 : g
    }

    func setGoal(_ n: Int) {
        goalAyahs = max(1, min(50, n))
        UserDefaults.standard.set(goalAyahs, forKey: key + ".goal")
    }

    func markReminderRead() {
        reminderDone = true
        UserDefaults.standard.set(true, forKey: key + ".reminder")
    }

    func addAyahProgress(_ n: Int = 1) {
        rollIfNeeded()
        doneAyahs = min(goalAyahs * 3, doneAyahs + n)
        UserDefaults.standard.set(doneAyahs, forKey: key + ".done")
    }

    var progress: Double {
        guard goalAyahs > 0 else { return 0 }
        return min(1, Double(doneAyahs) / Double(goalAyahs))
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

/// Lightweight snapshot for a future Home Screen widget (no separate App ID yet).
enum WidgetSnapshot {
    static func writeReminder(_ item: ReminderItem) {
        let d = UserDefaults.standard
        d.set(item.kind, forKey: "beummati.widget.kind")
        d.set(item.ref, forKey: "beummati.widget.ref")
        d.set(item.title, forKey: "beummati.widget.title")
        d.set(item.english, forKey: "beummati.widget.english")
        d.set(item.arabic, forKey: "beummati.widget.arabic")
        d.set(Date().timeIntervalSince1970, forKey: "beummati.widget.updated")
    }

    static func writeSeriesReminder(_ item: ReminderItem) {
        let d = UserDefaults.standard
        d.set(item.title, forKey: "beummati.seriesNotify.title")
        d.set(item.ref, forKey: "beummati.seriesNotify.ref")
        d.set(item.english, forKey: "beummati.seriesNotify.english")
        d.set(item.librarySeriesID, forKey: "beummati.seriesNotify.seriesID")
        d.set(item.libraryChapterID, forKey: "beummati.seriesNotify.chapterID")
        // Prefer series text for the daily ping when available
        d.set(item.title.isEmpty ? "Series reminder" : item.title, forKey: "beummati.widget.title")
        d.set(item.ref, forKey: "beummati.widget.ref")
        d.set(item.english, forKey: "beummati.widget.english")
        d.set(item.kind, forKey: "beummati.widget.kind")
    }

    static func writePrayer(_ day: PrayerDay, nextName: String, nextTime: String) {
        let d = UserDefaults.standard
        d.set(day.hijriDate, forKey: "beummati.widget.hijri")
        d.set(nextName, forKey: "beummati.widget.nextName")
        d.set(nextTime, forKey: "beummati.widget.nextTime")
        if let data = try? JSONEncoder().encode(day) {
            d.set(data, forKey: "beummati.widget.prayerDay")
        }
    }
}
