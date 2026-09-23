import Foundation

struct TafsirEntry: Hashable {
    let surah: Int
    let ayah: Int
    let text: String
}

actor TafsirAPI {
    static let shared = TafsirAPI()

    private let slug = "ur-tafseer-ibn-e-kaseer"
    private let base = "https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir"

    /// Bundled Urdu Ibn Kathir first, then disk cache, then one CDN request per surah.
    func chapter(surah: Int, verseCount: Int) async throws -> [TafsirEntry] {
        if let bundled = loadBundled(surah: surah), !bundled.isEmpty {
            await OfflineCache.shared.saveTafsirUrdu(surah: surah, entries: bundled)
            return bundled
        }
        if let cached = await OfflineCache.shared.loadTafsirUrdu(surah: surah), !cached.isEmpty {
            return cached
        }
        let remote = try await fetchChapterRemote(surah: surah)
        guard !remote.isEmpty else { throw APIError.decode }
        await OfflineCache.shared.saveTafsirUrdu(surah: surah, entries: remote)
        return remote
    }

    // MARK: - Bundle (TafsirUrdu/{surah}.json copied at build time from zip)

    private func loadBundled(surah: Int) -> [TafsirEntry]? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "\(surah)", withExtension: "json", subdirectory: "TafsirUrdu"),
            Bundle.main.url(forResource: "\(surah)", withExtension: "json", subdirectory: "Resources/TafsirUrdu"),
            Bundle.main.resourceURL?.appendingPathComponent("TafsirUrdu/\(surah).json")
        ]
        for url in candidates {
            guard let url, let data = try? Data(contentsOf: url) else { continue }
            if let entries = parseEntries(data) { return entries }
        }
        return nil
    }

    // MARK: - Remote (single JSON per surah — not one request per ayah)

    private func fetchChapterRemote(surah: Int) async throws -> [TafsirEntry] {
        let url = URL(string: "\(base)/\(slug)/\(surah).json")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw APIError.badResponse
        }
        return parseSpa5kChapter(data, surah: surah)
    }

    private func parseSpa5kChapter(_ data: Data, surah: Int) -> [TafsirEntry] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ayahs = json["ayahs"] as? [[String: Any]] else {
            return parseEntries(data) ?? []
        }
        return ayahs.compactMap { row -> TafsirEntry? in
            let ayah: Int
            if let a = row["ayah"] as? Int { ayah = a }
            else if let s = row["ayah"] as? String, let a = Int(s) { ayah = a }
            else { return nil }
            let clean = HTMLStrip.cleanPlain(row["text"] as? String ?? "")
            guard !clean.isEmpty else { return nil }
            return TafsirEntry(surah: surah, ayah: ayah, text: clean)
        }
        .sorted { $0.ayah < $1.ayah }
    }

    private func parseEntries(_ data: Data) -> [TafsirEntry]? {
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        let list = rows.compactMap { row -> TafsirEntry? in
            let surah: Int
            if let s = row["surah"] as? Int { surah = s }
            else if let s = row["surah"] as? String, let v = Int(s) { surah = v }
            else { return nil }
            let ayah: Int
            if let a = row["ayah"] as? Int { ayah = a }
            else if let a = row["ayah"] as? String, let v = Int(a) { ayah = v }
            else { return nil }
            let text = row["text"] as? String ?? ""
            guard !text.isEmpty else { return nil }
            return TafsirEntry(surah: surah, ayah: ayah, text: text)
        }
        return list.isEmpty ? nil : list.sorted { $0.ayah < $1.ayah }
    }
}
