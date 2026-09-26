import Foundation
import Combine

enum OfflinePackId: String, CaseIterable, Identifiable {
    case quran
    case hadith
    case quranAudio
    case quranAudioMushaf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quran: return "Qur’an"
        case .hadith: return "Hadith library"
        case .quranAudio: return "Qur’an audio (starter)"
        case .quranAudioMushaf: return "Qur’an audio (full mushaf)"
        }
    }

    var blurb: String {
        switch self {
        case .quran:
            return "Arabic with your English & Urdu translations — all 114 surahs."
        case .hadith:
            return "Bukhari, Muslim, Tirmidhi, Abu Dawud, Nasai, Ibn Majah & Malik (Arabic · English · Urdu)."
        case .quranAudio:
            return "Mishary Alafasy for Al-Fatiha, Yasin, Ar-Rahman, Al-Mulk, and the three Quls."
        case .quranAudioMushaf:
            return "Complete Alafasy Arabic recitation — all 6,236 ayahs. Large download; Wi‑Fi recommended."
        }
    }

    var sizeHint: String {
        switch self {
        case .quran: return "~25 MB"
        case .hadith: return "~80 MB"
        case .quranAudio: return "~few MB"
        case .quranAudioMushaf: return "~800 MB+"
        }
    }
}

enum OfflinePackStatus: Equatable {
    case notDownloaded
    case downloading
    case ready
    case failed(String)
}

struct OfflinePackState: Identifiable, Equatable {
    var id: OfflinePackId { pack }
    let pack: OfflinePackId
    var status: OfflinePackStatus = .notDownloaded
    var progress: Double = 0
    var detail: String = ""
}

/// Multi-pack offline manager — parity with Android `OfflinePacks`.
@MainActor
final class OfflinePacks: ObservableObject {
    static let shared = OfflinePacks()

    @Published private(set) var packs: [OfflinePackState]
    @Published private(set) var busy = false

    private var downloadTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let keyPrefix = "beummati.offline.pack."

    private init() {
        packs = OfflinePackId.allCases.map { OfflinePackState(pack: $0) }
        refreshStatuses()
    }

    func isReady(_ id: OfflinePackId) -> Bool {
        defaults.bool(forKey: keyPrefix + id.rawValue)
    }

    func refreshStatuses() {
        packs = OfflinePackId.allCases.map { id in
            var row = packs.first(where: { $0.pack == id }) ?? OfflinePackState(pack: id)
            if case .downloading = row.status, busy {
                return row
            }
            if isReady(id) {
                row.status = .ready
                row.progress = 1
                row.detail = "On this device"
            } else if case .failed = row.status {
                // keep failure
            } else {
                row.status = .notDownloaded
                row.progress = 0
                row.detail = ""
            }
            return row
        }
    }

    func download(_ ids: [OfflinePackId]) {
        let wanted = ids.filter { !isReady($0) }
        guard !wanted.isEmpty else { return }
        downloadTask?.cancel()
        downloadTask = Task {
            busy = true
            defer {
                busy = false
                refreshStatuses()
            }
            for id in wanted {
                do {
                    try await downloadOne(id)
                    defaults.set(true, forKey: keyPrefix + id.rawValue)
                    setState(id) {
                        var s = $0
                        s.status = .ready
                        s.progress = 1
                        s.detail = "On this device"
                        return s
                    }
                } catch is CancellationError {
                    setState(id) {
                        var s = $0
                        s.status = .notDownloaded
                        s.progress = 0
                        s.detail = "Cancelled"
                        return s
                    }
                    break
                } catch {
                    setState(id) {
                        var s = $0
                        s.status = .failed(error.localizedDescription)
                        s.progress = 0
                        s.detail = ""
                        return s
                    }
                }
            }
        }
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        busy = false
        packs = packs.map { row in
            if case .downloading = row.status {
                var s = row
                s.status = .notDownloaded
                s.progress = 0
                s.detail = "Cancelled"
                return s
            }
            return row
        }
        refreshStatuses()
    }

    func remove(_ id: OfflinePackId) {
        Task {
            await clearPackFiles(id)
            defaults.set(false, forKey: keyPrefix + id.rawValue)
            setState(id) { _ in OfflinePackState(pack: id) }
        }
    }

    private func downloadOne(_ id: OfflinePackId) async throws {
        setState(id) {
            var s = $0
            s.status = .downloading
            s.progress = 0
            s.detail = "Starting…"
            return s
        }
        switch id {
        case .quran:
            _ = try await QuranAPI.shared.chapters()
            for n in 1...114 {
                try Task.checkCancellation()
                _ = try await QuranAPI.shared.ayahs(chapter: n)
                setState(id) {
                    var s = $0
                    s.progress = Double(n) / 114
                    s.detail = "Surah \(n) of 114"
                    return s
                }
            }
        case .hadith:
            let books = HadithAPI.catalog
            let total = max(books.reduce(0) { $0 + max($1.chapters.count, 1) }, 1)
            var done = 0
            var failures = 0
            for book in books {
                let chapters = book.chapters.isEmpty ? [1] : book.chapters.map(\.index)
                for ch in chapters {
                    try Task.checkCancellation()
                    do {
                        _ = try await HadithAPI.shared.chapter(book: book.slug, index: ch)
                    } catch {
                        failures += 1
                    }
                    done += 1
                    setState(id) {
                        var s = $0
                        s.progress = Double(done) / Double(total)
                        s.detail = "\(book.name) · \(ch)"
                        return s
                    }
                }
            }
            // Don't mark Ready if too many chapters failed (network / CDN outage).
            if failures > 0 && failures * 100 / total >= 10 {
                throw NSError(
                    domain: "OfflinePacks",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Hadith pack incomplete — \(failures) / \(total) chapters failed"]
                )
            }
        case .quranAudio:
            let pairs: [(Int, Int)] = [
                (1, 7), (36, 83), (55, 78), (67, 30), (112, 4), (113, 5), (114, 6)
            ]
            let total = pairs.reduce(0) { $0 + $1.1 }
            var done = 0
            for (surah, count) in pairs {
                for ayah in 1...count {
                    try Task.checkCancellation()
                    _ = try await QuranAudioCache.shared.ensureArabic(surah: surah, ayah: ayah)
                    done += 1
                    setState(id) {
                        var s = $0
                        s.progress = Double(done) / Double(total)
                        s.detail = "Surah \(surah) · ayah \(ayah)"
                        return s
                    }
                }
            }
        case .quranAudioMushaf:
            let counts = QuranAudioCache.ayahCounts
            let total = max(counts.reduce(0, +), 1)
            var done = 0
            for surah in 1...114 {
                let count = counts[surah - 1]
                for ayah in 1...count {
                    try Task.checkCancellation()
                    _ = try await QuranAudioCache.shared.ensureArabic(surah: surah, ayah: ayah)
                    done += 1
                    if done % 5 == 0 || ayah == count {
                        setState(id) {
                            var s = $0
                            s.progress = Double(done) / Double(total)
                            s.detail = "Surah \(surah) · \(done) / \(total)"
                            return s
                        }
                    }
                }
            }
        }
    }

    private func clearPackFiles(_ id: OfflinePackId) async {
        switch id {
        case .quran:
            await OfflineCache.shared.clearQuran()
        case .hadith:
            await OfflineCache.shared.clearHadith()
        case .quranAudio:
            if isReady(.quranAudioMushaf) { return }
            await QuranAudioCache.shared.clearSurahs(QuranAudioCache.starterSurahs)
        case .quranAudioMushaf:
            if isReady(.quranAudio) {
                await QuranAudioCache.shared.clearExceptSurahs(QuranAudioCache.starterSurahs)
            } else {
                await QuranAudioCache.shared.clearAll()
            }
        }
    }

    private func setState(_ id: OfflinePackId, transform: (OfflinePackState) -> OfflinePackState) {
        packs = packs.map { $0.pack == id ? transform($0) : $0 }
    }
}
