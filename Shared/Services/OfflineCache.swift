import Foundation

/// Disk cache for Qur’an chapters + surah ayahs. Text-only (~few MB for a pack).
actor OfflineCache {
    static let shared = OfflineCache()

    private var dir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("nur-offline", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func chaptersURL() -> URL { dir.appendingPathComponent("chapters.json") }
    func surahURL(_ id: Int) -> URL { dir.appendingPathComponent("surah-\(id).json") }
    func surahURL(_ id: Int, en: Int, ur: Int) -> URL {
        dir.appendingPathComponent("surah-\(id)-en\(en)-ur\(ur).json")
    }
    func tafsirUrduURL(_ surah: Int) -> URL { dir.appendingPathComponent("tafsir-ur-ibn-kathir-v2-\(surah).json") }

    func saveChapters(_ chapters: [QuranChapter]) {
        let rows = chapters.map {
            [
                "id": $0.id,
                "nameArabic": $0.nameArabic,
                "nameSimple": $0.nameSimple,
                "versesCount": $0.versesCount,
                "revelationPlace": $0.revelationPlace
            ] as [String: Any]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rows) else { return }
        try? data.write(to: chaptersURL(), options: .atomic)
    }

    func loadChapters() -> [QuranChapter]? {
        guard let data = try? Data(contentsOf: chaptersURL()),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let list = rows.compactMap { c -> QuranChapter? in
            guard let id = c["id"] as? Int else { return nil }
            return QuranChapter(
                id: id,
                nameArabic: c["nameArabic"] as? String ?? "",
                nameSimple: c["nameSimple"] as? String ?? "",
                versesCount: c["versesCount"] as? Int ?? 0,
                revelationPlace: c["revelationPlace"] as? String ?? ""
            )
        }
        return list.isEmpty ? nil : list
    }

    func saveAyahs(chapter: Int, ayahs: [QuranAyah], en: Int = 0, ur: Int = 0) {
        let rows: [[String: String]] = ayahs.map {
            [
                "key": $0.key,
                "uthmani": $0.arabicUthmani,
                "indopak": $0.arabicIndopak,
                "english": $0.english,
                "urdu": $0.urdu
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rows) else { return }
        let url = (en > 0 && ur > 0) ? surahURL(chapter, en: en, ur: ur) : surahURL(chapter)
        try? data.write(to: url, options: .atomic)
    }

    func loadAyahs(chapter: Int, en: Int = 0, ur: Int = 0) -> [QuranAyah]? {
        let url = (en > 0 && ur > 0) ? surahURL(chapter, en: en, ur: ur) : surahURL(chapter)
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return nil }
        let list = rows.map {
            QuranAyah(
                key: $0["key"] ?? "",
                arabicUthmani: $0["uthmani"] ?? "",
                arabicIndopak: $0["indopak"] ?? "",
                english: $0["english"] ?? "",
                urdu: $0["urdu"] ?? ""
            )
        }
        return list.isEmpty ? nil : list
    }

    func hasSurah(_ id: Int) -> Bool {
        FileManager.default.fileExists(atPath: surahURL(id).path)
    }

    func cachedSurahIDs() -> [Int] {
        (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil))?
            .compactMap { url -> Int? in
                let name = url.deletingPathExtension().lastPathComponent
                guard name.hasPrefix("surah-") else { return nil }
                return Int(name.replacingOccurrences(of: "surah-", with: ""))
            }
            .sorted() ?? []
    }

    func removeSurah(_ id: Int) {
        try? FileManager.default.removeItem(at: surahURL(id))
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: dir)
        _ = dir
    }

    func saveTafsirUrdu(surah: Int, entries: [TafsirEntry]) {
        let rows: [[String: Any]] = entries.map {
            ["surah": $0.surah, "ayah": $0.ayah, "text": $0.text]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: rows) else { return }
        try? data.write(to: tafsirUrduURL(surah), options: .atomic)
    }

    func loadTafsirUrdu(surah: Int) -> [TafsirEntry]? {
        guard let data = try? Data(contentsOf: tafsirUrduURL(surah)),
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let list = rows.compactMap { row -> TafsirEntry? in
            guard let s = row["surah"] as? Int, let a = row["ayah"] as? Int else { return nil }
            return TafsirEntry(surah: s, ayah: a, text: row["text"] as? String ?? "")
        }
        return list.isEmpty ? nil : list
    }

    func approximateBytes() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { sum, url in
            let n = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(n)
        }
    }
}
