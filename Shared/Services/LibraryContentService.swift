import Foundation

/// Loads long-form library text from the app bundle, optional remote pack, or on-device import folder.
actor LibraryContentService {
    static let shared = LibraryContentService()

    private let remoteBaseKey = "beummati.library.remoteBase"
    private var importRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LibraryPack", isDirectory: true)
    }

    func loadChapter(seriesID: String, chapterID: String) async throws -> LibraryChapterBody {
        if let local = loadBundled(seriesID: seriesID, chapterID: chapterID) {
            return local
        }
        if let imported = loadFromDisk(seriesID: seriesID, chapterID: chapterID) {
            return imported
        }
        if let remote = try? await loadRemote(seriesID: seriesID, chapterID: chapterID) {
            try? saveToDisk(seriesID: seriesID, chapterID: chapterID, body: remote)
            return remote
        }
        throw LibraryContentError.missing
    }

    func importPackFile(from url: URL, seriesID: String, chapterID: String) throws {
        let data = try Data(contentsOf: url)
        let body = try JSONDecoder().decode(LibraryChapterBody.self, from: data)
        try saveToDisk(seriesID: seriesID, chapterID: chapterID, body: body)
    }

    func hasLocalChapter(seriesID: String, chapterID: String) -> Bool {
        loadBundled(seriesID: seriesID, chapterID: chapterID) != nil
            || loadFromDisk(seriesID: seriesID, chapterID: chapterID) != nil
    }

    private func expandedBundleSubdirectory(for seriesID: String) -> String? {
        switch seriesID {
        case "tareekh-ibn-kathir-urdu":
            return "TareekhUrdu"
        default:
            return nil
        }
    }

    private func loadBundled(seriesID: String, chapterID: String) -> LibraryChapterBody? {
        var candidates: [URL?] = []
        if let sub = expandedBundleSubdirectory(for: seriesID) {
            candidates.append(contentsOf: [
                Bundle.main.url(forResource: chapterID, withExtension: "json", subdirectory: sub),
                Bundle.main.url(forResource: chapterID, withExtension: "json", subdirectory: "Resources/\(sub)"),
                Bundle.main.resourceURL?.appendingPathComponent("\(sub)/\(chapterID).json")
            ])
        }
        candidates.append(contentsOf: [
            Bundle.main.url(forResource: "\(seriesID)__\(chapterID)", withExtension: "json"),
            Bundle.main.url(forResource: "\(seriesID)__\(chapterID)", withExtension: "json", subdirectory: "Resources"),
            Bundle.main.url(forResource: chapterID, withExtension: "json", subdirectory: "Library/\(seriesID)"),
            Bundle.main.url(forResource: chapterID, withExtension: "json", subdirectory: "Resources/Library/\(seriesID)")
        ])
        for url in candidates.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let body = try? JSONDecoder().decode(LibraryChapterBody.self, from: data) {
                return body
            }
        }
        return nil
    }

    private func loadFromDisk(seriesID: String, chapterID: String) -> LibraryChapterBody? {
        let url = importRoot.appendingPathComponent(seriesID).appendingPathComponent("\(chapterID).json")
        guard let data = try? Data(contentsOf: url),
              let body = try? JSONDecoder().decode(LibraryChapterBody.self, from: data)
        else { return nil }
        return body
    }

    private func saveToDisk(seriesID: String, chapterID: String, body: LibraryChapterBody) throws {
        let dir = importRoot.appendingPathComponent(seriesID, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(chapterID).json")
        let data = try JSONEncoder().encode(body)
        try data.write(to: url, options: .atomic)
    }

    private func loadRemote(seriesID: String, chapterID: String) async throws -> LibraryChapterBody {
        let base = UserDefaults.standard.string(forKey: remoteBaseKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !base.isEmpty else { throw LibraryContentError.missing }
        let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
        let url = URL(string: "\(trimmed)/\(seriesID)/\(chapterID).json")!
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw APIError.badResponse
        }
        return try JSONDecoder().decode(LibraryChapterBody.self, from: data)
    }
}

enum LibraryContentError: LocalizedError {
    case missing

    var errorDescription: String? {
        switch self {
        case .missing:
            return "This chapter is not downloaded yet. Import a JSON chapter pack or set a content server URL in Settings."
        }
    }
}
