import Foundation

enum LibrarySeriesKind: String, Codable {
    case quranTafsir
    case chapters
    case sahaba
    case prophets
}

struct LibraryChapterMeta: Identifiable, Hashable, Codable {
    let id: String
    let index: Int?
    let title: String
    let group: String?
    let volume: Int?
    let volumeTitle: String?
    let youtubeId: String?
    let srtEnglish: String?
    let srtUrdu: String?

    init(
        id: String,
        index: Int? = nil,
        title: String,
        group: String? = nil,
        volume: Int? = nil,
        volumeTitle: String? = nil,
        youtubeId: String? = nil,
        srtEnglish: String? = nil,
        srtUrdu: String? = nil
    ) {
        self.id = id
        self.index = index
        self.title = title
        self.group = group
        self.volume = volume
        self.volumeTitle = volumeTitle
        self.youtubeId = youtubeId
        self.srtEnglish = srtEnglish
        self.srtUrdu = srtUrdu
    }
}

struct LibrarySeries: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let kind: LibrarySeriesKind
    let primaryLanguage: String
    let attribution: String
    let chapters: [LibraryChapterMeta]?

    var chapterCount: Int { chapters?.count ?? 0 }
}

struct LibraryCatalogRoot: Codable {
    let series: [LibrarySeries]
}

struct LibraryChapterBody: Codable, Hashable {
    let title: String
    let urdu: String
    let english: String
    let reference: String
    let arabic: String?
    let youtubeId: String?
    let srtEnglish: String?
    let srtUrdu: String?
    let source: String?

    init(
        title: String,
        urdu: String,
        english: String,
        reference: String,
        arabic: String? = nil,
        youtubeId: String? = nil,
        srtEnglish: String? = nil,
        srtUrdu: String? = nil,
        source: String? = nil
    ) {
        self.title = title
        self.urdu = urdu
        self.english = english
        self.reference = reference
        self.arabic = arabic
        self.youtubeId = youtubeId
        self.srtEnglish = srtEnglish
        self.srtUrdu = srtUrdu
        self.source = source
    }
}

struct SahabaStory: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let title: String
    let urdu: String
    let english: String
    let reference: String
    let theme: String
}

enum LibraryCatalog {
    static let all: [LibrarySeries] = load().series

    static func series(id: String) -> LibrarySeries? {
        all.first { $0.id == id }
    }

    private static func load() -> LibraryCatalogRoot {
        let urls: [URL?] = [
            Bundle.main.url(forResource: "LibraryCatalog", withExtension: "json"),
            Bundle.main.url(forResource: "LibraryCatalog", withExtension: "json", subdirectory: "Resources")
        ]
        for url in urls.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(LibraryCatalogRoot.self, from: data) {
                return decoded
            }
        }
        return LibraryCatalogRoot(series: [])
    }
}

enum SahabaLibrary {
    static let stories: [SahabaStory] = load()

    private static func load() -> [SahabaStory] {
        let urls: [URL?] = [
            Bundle.main.url(forResource: "SahabaStories", withExtension: "json"),
            Bundle.main.url(forResource: "SahabaStories", withExtension: "json", subdirectory: "Resources")
        ]
        for url in urls.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([SahabaStory].self, from: data) {
                return decoded.filter {
                    !$0.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
        }
        return []
    }
}


enum ProphetsLibrary {
    static let stories: [SahabaStory] = load()

    private static func load() -> [SahabaStory] {
        let urls: [URL?] = [
            Bundle.main.url(forResource: "ProphetsStories", withExtension: "json"),
            Bundle.main.url(forResource: "ProphetsStories", withExtension: "json", subdirectory: "Resources")
        ]
        for url in urls.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([SahabaStory].self, from: data) {
                return decoded.filter {
                    !$0.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
        }
        return []
    }
}
