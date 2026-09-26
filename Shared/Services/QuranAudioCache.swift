import Foundation

/// Disk cache for everyayah.com Alafasy MP3s — mirrors Android `QuranAudioCache`.
actor QuranAudioCache {
    static let shared = QuranAudioCache()

    static let alafasyFolder = "Alafasy_128kbps"
    private static let everyayahBase = "https://everyayah.com/data"

    /// Surahs in the starter audio pack (same set as Android).
    static let starterSurahs: [Int] = [1, 36, 55, 67, 112, 113, 114]

    /// Hafs ayah counts 1…114.
    static let ayahCounts: [Int] = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
        54, 53, 89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
        29, 19, 36, 25, 22, 17, 19, 26, 30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
        11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6
    ]

    private var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("beummati-quran-audio/ar_alafasy", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func fileURL(surah: Int, ayah: Int) -> URL {
        let name = String(format: "%03d%03d.mp3", surah, ayah)
        return root.appendingPathComponent(name)
    }

    func existingArabic(surah: Int, ayah: Int) -> URL? {
        let url = fileURL(surah: surah, ayah: ayah)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return size > 1024 ? url : nil
    }

    @discardableResult
    func ensureArabic(surah: Int, ayah: Int) async throws -> URL {
        if let existing = existingArabic(surah: surah, ayah: ayah) { return existing }
        let name = String(format: "%03d%03d", surah, ayah)
        guard let remote = URL(string: "\(Self.everyayahBase)/\(Self.alafasyFolder)/\(name).mp3") else {
            throw URLError(.badURL)
        }
        let (data, resp) = try await URLSession.shared.data(from: remote)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let dest = fileURL(surah: surah, ayah: ayah)
        try data.write(to: dest, options: .atomic)
        return dest
    }

    func downloadSurah(_ surah: Int, onProgress: @MainActor (Float, String) -> Void = { _, _ in }) async throws {
        let count = Self.ayahCounts[safe: surah - 1] ?? 0
        guard count > 0 else { return }
        for ayah in 1...count {
            try Task.checkCancellation()
            _ = try await ensureArabic(surah: surah, ayah: ayah)
            let p = Float(ayah) / Float(count)
            await onProgress(p, "Ayah \(ayah) / \(count)")
        }
    }

    func clearSurahs(_ surahs: [Int]) {
        for surah in surahs {
            let count = Self.ayahCounts[safe: surah - 1] ?? 0
            for ayah in 1...count {
                try? FileManager.default.removeItem(at: fileURL(surah: surah, ayah: ayah))
            }
        }
    }

    func clearExceptSurahs(_ keep: [Int]) {
        let keepSet = Set(keep)
        guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            guard name.count >= 3, let surah = Int(name.prefix(3)) else {
                try? FileManager.default.removeItem(at: file)
                continue
            }
            if !keepSet.contains(surah) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func clearAll() {
        try? FileManager.default.removeItem(at: root)
        _ = root
    }

    func approximateBytes() -> Int64 {
        guard let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { sum, url in
            let n = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + Int64(n)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
