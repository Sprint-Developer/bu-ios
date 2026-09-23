import Foundation

struct HadithChapter: Identifiable, Hashable, Codable {
    var id: Int { index }
    let index: Int
    let name: String
    let first: Int
    let last: Int
    let count: Int
}

struct HadithBookInfo: Identifiable, Hashable, Codable {
    var id: String { slug }
    let slug: String
    let name: String
    let hasUrdu: Bool
    let hadithCount: Int
    let chapters: [HadithChapter]
}

actor HadithAPI {
    static let shared = HadithAPI()
    private let base = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1"

    /// Static kitāb names + counts (from hadith-api info metadata).
    static let catalog: [HadithBookInfo] = {
        guard let url = Bundle.main.url(forResource: "HadithCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(CatalogRoot.self, from: data)
        else { return fallbackCatalog }
        return root.books
    }()

    /// Backward-compatible list used elsewhere.
    static var books: [HadithBook] {
        catalog.map { HadithBook(slug: $0.slug, name: $0.name, hasUrdu: $0.hasUrdu) }
    }

    private struct CatalogRoot: Codable {
        let books: [HadithBookInfo]
    }

    private static let fallbackCatalog: [HadithBookInfo] = [
        .init(slug: "bukhari", name: "Sahih al-Bukhari", hasUrdu: true, hadithCount: 7563, chapters: []),
        .init(slug: "muslim", name: "Sahih Muslim", hasUrdu: true, hadithCount: 7563, chapters: []),
        .init(slug: "nawawi", name: "40 Nawawi", hasUrdu: false, hadithCount: 42, chapters: [
            .init(index: 1, name: "Forty Hadith of an-Nawawi", first: 1, last: 42, count: 42)
        ]),
        .init(slug: "qudsi", name: "40 Hadith Qudsi", hasUrdu: false, hadithCount: 40, chapters: [
            .init(index: 1, name: "Hadith Qudsi", first: 1, last: 40, count: 40)
        ])
    ]

    func bookInfo(_ slug: String) -> HadithBookInfo? {
        Self.catalog.first { $0.slug == slug }
    }

    /// Hadiths in a named kitāb/chapter (author’s book section).
    func chapter(book: String, index: Int) async throws -> [HadithItem] {
        async let enData = fetchSectionEdition("eng-\(book)", section: index)
        async let arData = fetchSectionEdition("ara-\(book)", section: index)
        let urData: [RawHadith]
        if Self.catalog.first(where: { $0.slug == book })?.hasUrdu == true {
            urData = (try? await fetchSectionEdition("urd-\(book)", section: index)) ?? []
        } else {
            urData = []
        }
        return merge(book: book, ar: try await arData, en: try await enData, ur: urData)
    }

    /// Single hadith by global hadith number in the edition.
    func hadithByNumber(book: String, number: Int) async throws -> HadithItem {
        async let en = fetchNumberEdition("eng-\(book)", number: number)
        async let ar = fetchNumberEdition("ara-\(book)", number: number)
        let ur: RawHadith?
        if Self.catalog.first(where: { $0.slug == book })?.hasUrdu == true {
            ur = try? await fetchNumberEdition("urd-\(book)", number: number)
        } else {
            ur = nil
        }
        let enH = try await en
        let arH = try await ar
        return HadithItem(
            book: book,
            number: number,
            arabic: arH?.text ?? "",
            english: enH?.text ?? "",
            urdu: ur?.text ?? ""
        )
    }

    /// Find which kitāb contains a hadith number.
    func chapterContaining(book: String, number: Int) -> HadithChapter? {
        guard let info = bookInfo(book) else { return nil }
        return info.chapters.first { number >= $0.first && number <= $0.last }
    }

    /// Used by reminders: `number` is global hadith number when possible.
    func hadith(book: String, section sectionIndex: Int, number: Int) async throws -> HadithItem {
        // Prefer direct number fetch (correct for Bukhari #1, #8, etc.)
        if let byNum = try? await hadithByNumber(book: book, number: number),
           !byNum.english.isEmpty || !byNum.arabic.isEmpty {
            return byNum
        }
        let items = try await chapter(book: book, index: sectionIndex)
        if let hit = items.first(where: { $0.number == number }) { return hit }
        if number >= 1, number <= items.count { return items[number - 1] }
        throw APIError.badResponse
    }

    /// Legacy name used by search — now loads real kitāb sections.
    func section(book: String, index: Int) async throws -> [HadithItem] {
        try await chapter(book: book, index: index)
    }

    func search(query: String, book: String? = nil, maxSections: Int = 12, limit: Int = 40) async throws -> [HadithItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        let qLower = q.lowercased()
        let books = book.map { [$0] } ?? Self.catalog.map(\.slug)
        var hits: [HadithItem] = []
        var seen = Set<String>()

        // Numeric jump shortcut
        if let n = Int(q), books.count == 1 || book != nil {
            let slug = book ?? books[0]
            if let h = try? await hadithByNumber(book: slug, number: n) {
                return [h]
            }
        }

        for slug in books {
            let chapters = bookInfo(slug)?.chapters.map(\.index) ?? Array(1...maxSections)
            for i in chapters.prefix(maxSections) {
                guard let items = try? await chapter(book: slug, index: i) else { continue }
                for h in items {
                    let match = h.english.lowercased().contains(qLower)
                        || h.arabic.contains(q)
                        || h.urdu.contains(q)
                        || "\(h.number)" == q
                    guard match else { continue }
                    let id = "\(h.book)-\(h.number)"
                    guard !seen.contains(id) else { continue }
                    seen.insert(id)
                    hits.append(h)
                    if hits.count >= limit { return hits }
                }
            }
        }
        return hits
    }

    // MARK: - Networking

    private struct RawHadith {
        let number: Int
        let text: String
    }

    private func merge(book: String, ar: [RawHadith], en: [RawHadith], ur: [RawHadith]) -> [HadithItem] {
        var byNum: [Int: (ar: String, en: String, ur: String)] = [:]
        for h in ar { byNum[h.number, default: ("", "", "")].ar = h.text }
        for h in en { byNum[h.number, default: ("", "", "")].en = h.text }
        for h in ur { byNum[h.number, default: ("", "", "")].ur = h.text }
        return byNum.keys.sorted().map { num in
            let t = byNum[num]!
            return HadithItem(book: book, number: num, arabic: t.ar, english: t.en, urdu: t.ur)
        }
    }

    /// Correct path: editions/{edition}/sections/{kitab}.json
    private func fetchSectionEdition(_ edition: String, section: Int) async throws -> [RawHadith] {
        let url = URL(string: "\(base)/editions/\(edition)/sections/\(section).json")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return parseHadiths(data)
    }

    /// Per-hadith file: editions/{edition}/{number}.json
    private func fetchNumberEdition(_ edition: String, number: Int) async throws -> RawHadith? {
        let url = URL(string: "\(base)/editions/\(edition)/\(number).json")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return parseHadiths(data).first
    }

    private func parseHadiths(_ data: Data) -> [RawHadith] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let list = json["hadiths"] as? [[String: Any]] ?? []
        return list.compactMap { h in
            let n: Int
            if let i = h["hadithnumber"] as? Int { n = i }
            else if let d = h["hadithnumber"] as? Double { n = Int(d) }
            else { return nil }
            let text = HTMLStrip.clean(h["text"] as? String ?? "")
            return RawHadith(number: n, text: text)
        }
    }
}
