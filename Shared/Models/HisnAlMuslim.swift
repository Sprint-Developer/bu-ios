import Foundation

struct DuaShortcut: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let categoryIds: [Int]
}

struct DuaCategory: Identifiable, Hashable, Codable {
    let id: Int
    let titleEn: String
    let titleAr: String
    let duas: [DuaItem]
}

struct DuaItem: Identifiable, Hashable, Codable {
    let id: String
    let categoryId: Int
    let arabic: String
    let transliteration: String
    let english: String
    let reference: String
    let count: Int
}

private struct HisnRoot: Codable {
    let source: String
    let note: String
    let categories: [DuaCategory]
    let shortcuts: [DuaShortcut]?
}

enum HisnAlMuslim {
    private static let root: HisnRoot = load()

    static var source: String { root.source }
    static var note: String { root.note }
    static var categories: [DuaCategory] { root.categories }
    static var shortcuts: [DuaShortcut] {
        root.shortcuts ?? []
    }

    static var allDuas: [DuaItem] {
        categories.flatMap(\.duas)
    }

    static func category(id: Int) -> DuaCategory? {
        categories.first { $0.id == id }
    }

    static func duas(for shortcut: DuaShortcut) -> [DuaItem] {
        let set = Set(shortcut.categoryIds)
        return categories.filter { set.contains($0.id) }.flatMap(\.duas)
    }

    static func search(_ query: String) -> [DuaItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return allDuas.filter {
            $0.english.lowercased().contains(q)
                || $0.arabic.contains(query)
                || $0.transliteration.lowercased().contains(q)
                || $0.reference.lowercased().contains(q)
        }
    }

    private static func load() -> HisnRoot {
        let urls: [URL?] = [
            Bundle.main.url(forResource: "HisnAlMuslim", withExtension: "json"),
            Bundle.main.url(forResource: "HisnAlMuslim", withExtension: "json", subdirectory: "Resources")
        ]
        for url in urls.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(HisnRoot.self, from: data) {
                let cats = decoded.categories.map { cat in
                    DuaCategory(
                        id: cat.id,
                        titleEn: cat.titleEn,
                        titleAr: cat.titleAr,
                        duas: cat.duas.filter {
                            !$0.arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                && !$0.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                    )
                }.filter { !$0.duas.isEmpty }
                return HisnRoot(source: decoded.source, note: decoded.note, categories: cats, shortcuts: decoded.shortcuts)
            }
        }
        return HisnRoot(source: "", note: "", categories: [], shortcuts: [])
    }
}
