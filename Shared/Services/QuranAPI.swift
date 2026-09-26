import Foundation

enum APIError: Error { case badURL, badResponse, decode }

struct TranslationChoice: Identifiable, Hashable {
    let id: Int
    let label: String
}

actor QuranAPI {
    static let shared = QuranAPI()
    private let base = "https://api.quran.com/api/v4"
    private let textFields = "text_uthmani,text_indopak"

    static let englishChoices: [TranslationChoice] = [
        .init(id: 20, label: "Saheeh International"),
        .init(id: 85, label: "Abdel Haleem"),
        .init(id: 149, label: "Bridges’ translation"),
        .init(id: 84, label: "Taqi Usmani"),
        .init(id: 95, label: "Maududi (English)"),
        .init(id: 22, label: "Yusuf Ali"),
        .init(id: 19, label: "Pickthall"),
        .init(id: 203, label: "Hilali & Khan")
    ]
    static let urduChoices: [TranslationChoice] = [
        .init(id: 54, label: "Junagarhi"),
        .init(id: 234, label: "Jalandhari"),
        .init(id: 97, label: "Maududi (Tafheem)"),
        .init(id: 158, label: "Bayan-ul-Quran"),
        .init(id: 151, label: "Tafsir-e-Usmani"),
        .init(id: 819, label: "Wahiduddin Khan")
    ]

    private var enID: Int {
        let v = UserDefaults.standard.integer(forKey: "beummati.enTranslationID")
        return v == 0 ? 85 : v
    }
    private var urID: Int {
        let v = UserDefaults.standard.integer(forKey: "beummati.urTranslationID")
        return v == 0 ? 54 : v
    }

    func chapters() async throws -> [QuranChapter] {
        do {
            let url = URL(string: "\(base)/chapters?language=en")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let list = json?["chapters"] as? [[String: Any]] ?? []
            let chapters = list.compactMap { c -> QuranChapter? in
                guard let id = c["id"] as? Int else { return nil }
                return QuranChapter(
                    id: id,
                    nameArabic: c["name_arabic"] as? String ?? "",
                    nameSimple: c["name_simple"] as? String ?? "",
                    versesCount: c["verses_count"] as? Int ?? 0,
                    revelationPlace: (c["revelation_place"] as? String ?? "").capitalized
                )
            }
            await OfflineCache.shared.saveChapters(chapters)
            return chapters
        } catch {
            if let cached = await OfflineCache.shared.loadChapters() { return cached }
            throw error
        }
    }

    func ayahs(chapter: Int) async throws -> [QuranAyah] {
        do {
            var page = 1
            var all: [QuranAyah] = []
            let en = enID, ur = urID
            while true {
                let url = URL(string: "\(base)/verses/by_chapter/\(chapter)?language=en&translations=\(en),\(ur)&fields=\(textFields)&per_page=50&page=\(page)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let verses = json?["verses"] as? [[String: Any]] ?? []
                if verses.isEmpty { break }
                for v in verses {
                    all.append(parseVerse(v, en: en, ur: ur))
                }
                let meta = json?["pagination"] as? [String: Any]
                let next = meta?["next_page"] as? Int
                if let next { page = next } else { break }
            }
            await OfflineCache.shared.saveAyahs(chapter: chapter, ayahs: all, en: en, ur: ur)
            return all
        } catch {
            if let cached = await OfflineCache.shared.loadAyahs(chapter: chapter, en: enID, ur: urID) { return cached }
            throw error
        }
    }

    /// All ayahs in a juz (parah) via quran.com `verses/by_juz/{n}` — same fields as by_chapter.
    /// Falls back to assembling from offline surah cache when the network fails.
    func ayahs(juz: Int) async throws -> [QuranAyah] {
        do {
            var page = 1
            var all: [QuranAyah] = []
            let en = enID, ur = urID
            while true {
                let url = URL(string: "\(base)/verses/by_juz/\(juz)?language=en&translations=\(en),\(ur)&fields=\(textFields)&per_page=50&page=\(page)")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let verses = json?["verses"] as? [[String: Any]] ?? []
                if verses.isEmpty { break }
                for v in verses {
                    all.append(parseVerse(v, en: en, ur: ur))
                }
                let meta = json?["pagination"] as? [String: Any]
                let next = meta?["next_page"] as? Int
                if let next { page = next } else { break }
            }
            if !all.isEmpty { return all }
            if let cached = await ayahsFromSurahCache(juz: juz) { return cached }
            return all
        } catch {
            if let cached = await ayahsFromSurahCache(juz: juz) { return cached }
            throw error
        }
    }

    /// Rebuild a juz from cached surah files (full/starter Qur’an offline pack).
    private func ayahsFromSurahCache(juz: Int) async -> [QuranAyah]? {
        guard let info = JuzCatalog.get(juz) else { return nil }
        guard let start = parseKey(info.startKey), let end = parseKey(info.endKey) else { return nil }
        let en = enID, ur = urID
        var out: [QuranAyah] = []
        for surah in start.0...end.0 {
            var ayahs = await OfflineCache.shared.loadAyahs(chapter: surah, en: en, ur: ur)
            if ayahs == nil {
                ayahs = await OfflineCache.shared.loadAyahs(chapter: surah)
            }
            guard let ayahs else { return nil }
            for ayah in ayahs {
                let n = ayah.numberInSurah
                if surah == start.0 && n < start.1 { continue }
                if surah == end.0 && n > end.1 { continue }
                out.append(ayah)
            }
        }
        return out.isEmpty ? nil : out
    }

    private func parseKey(_ key: String) -> (Int, Int)? {
        let parts = key.split(separator: ":")
        guard parts.count == 2, let s = Int(parts[0]), let a = Int(parts[1]) else { return nil }
        return (s, a)
    }

    func verse(key: String) async throws -> QuranAyah {
        let parts = key.split(separator: ":")
        guard parts.count == 2, let ch = Int(parts[0]), let _ = Int(parts[1]) else { throw APIError.badURL }
        let en = enID, ur = urID
        if let cached = await OfflineCache.shared.loadAyahs(chapter: ch, en: en, ur: ur),
           let hit = cached.first(where: { $0.key == key }) {
            return hit
        }
        let url = URL(string: "\(base)/verses/by_key/\(key)?translations=\(en),\(ur)&fields=\(textFields)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let v = json?["verse"] as? [String: Any] else { throw APIError.decode }
        return parseVerse(v, en: en, ur: ur)
    }

    func search(query: String) async throws -> [QuranAyah] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Prefer Urdu search when the typed query contains Arabic/Urdu script.
        let hasArabicScript = query.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
        let lang = hasArabicScript ? "ur" : "en"
        let url = URL(string: "\(base)/search?q=\(q)&size=20&language=\(lang)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let search = json?["search"] as? [String: Any]
        let results = search?["results"] as? [[String: Any]] ?? []
        var out: [QuranAyah] = []
        for r in results.prefix(20) {
            let key = r["verse_key"] as? String ?? ""
            if let detailed = try? await verse(key: key) {
                out.append(detailed)
            }
        }
        return out
    }

    private func parseVerse(_ v: [String: Any], en: Int, ur: Int) -> QuranAyah {
        let key = v["verse_key"] as? String ?? ""
        let uthmani = v["text_uthmani"] as? String ?? ""
        let indopak = v["text_indopak"] as? String ?? ""
        var enT = "", urT = ""
        for t in (v["translations"] as? [[String: Any]] ?? []) {
            let rid = t["resource_id"] as? Int ?? 0
            let text = HTMLStrip.clean(t["text"] as? String ?? "")
            if rid == en { enT = text }
            if rid == ur { urT = text }
        }
        return QuranAyah(
            key: key,
            arabicUthmani: uthmani,
            arabicIndopak: indopak,
            english: enT,
            urdu: urT
        )
    }
}
