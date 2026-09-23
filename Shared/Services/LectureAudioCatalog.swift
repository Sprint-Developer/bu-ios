import Foundation

struct LectureAudioTrack: Identifiable, Hashable, Codable {
    var id: String { "\(seriesID)/\(chapterID)" }
    let seriesID: String
    let chapterID: String
    let title: String
    let audioUrl: String
    let srtFile: String?
    let audioName: String?
}

struct LectureAudioCatalogRoot: Codable {
    let source: String?
    let hosts: String?
    let attribution: String?
    let tracks: [LectureAudioTrack]
}

enum LectureAudioCatalog {
    private static let root: LectureAudioCatalogRoot = load()

    static var attribution: String {
        root.attribution ?? "Audio streamed from Internet Archive"
    }

    static func track(seriesID: String, chapterID: String) -> LectureAudioTrack? {
        root.tracks.first { $0.seriesID == seriesID && $0.chapterID == chapterID }
    }

    static func hasAudio(seriesID: String, chapterID: String) -> Bool {
        track(seriesID: seriesID, chapterID: chapterID) != nil
    }

    private static func load() -> LectureAudioCatalogRoot {
        let urls: [URL?] = [
            Bundle.main.url(forResource: "LectureAudioCatalog", withExtension: "json"),
            Bundle.main.url(forResource: "LectureAudioCatalog", withExtension: "json", subdirectory: "Resources")
        ]
        for url in urls.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(LectureAudioCatalogRoot.self, from: data) {
                return decoded
            }
        }
        return LectureAudioCatalogRoot(source: nil, hosts: nil, attribution: nil, tracks: [])
    }
}

// MARK: - SRT cues

struct SRTCue: Identifiable, Hashable {
    let id: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

enum SubtitleLang: String, CaseIterable, Identifiable {
    case english, urdu, arabic
    var id: String { rawValue }
    var label: String {
        switch self {
        case .english: return "English"
        case .urdu: return "Urdu"
        case .arabic: return "Arabic"
        }
    }
}

enum SRTCueParser {
    /// Resolve the best SRT filename for a chapter + language.
    static func resolveFile(
        track: LectureAudioTrack,
        chapter: LibraryChapterMeta,
        lang: SubtitleLang
    ) -> String? {
        switch lang {
        case .urdu:
            if let u = chapter.srtUrdu, !u.isEmpty, bundleContainsSRT(u) { return u }
            // Fall back to English timed file if Urdu missing
            return resolveFile(track: track, chapter: chapter, lang: .english)
        case .arabic, .english:
            if let en = chapter.srtEnglish, !en.isEmpty, bundleContainsSRT(en) { return en }
            if let f = track.srtFile, !f.isEmpty, bundleContainsSRT(f) { return f }
            return track.srtFile ?? chapter.srtEnglish
        }
    }

    static func bundleContainsSRT(_ file: String) -> Bool {
        !loadURL(named: file).isEmpty
    }

    static func loadURL(named file: String) -> [URL] {
        let stem = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension.isEmpty ? "srt" : (file as NSString).pathExtension
        return [
            Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: "AlQalam/srt"),
            Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: "Resources/AlQalam/srt"),
            Bundle.main.resourceURL?.appendingPathComponent("AlQalam/srt/\(stem).\(ext)")
        ].compactMap { $0 }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func load(named file: String?) -> [SRTCue] {
        guard let file, !file.isEmpty else { return [] }
        for url in loadURL(named: file) {
            if let raw = try? String(contentsOf: url, encoding: .utf8) {
                let cues = parse(raw)
                if !cues.isEmpty { return cues }
            }
            if let raw = try? String(contentsOf: url, encoding: .isoLatin1) {
                let cues = parse(raw)
                if !cues.isEmpty { return cues }
            }
            // UTF-16 LE/BE some exports
            if let data = try? Data(contentsOf: url),
               let raw = String(data: data, encoding: .utf16) {
                let cues = parse(raw)
                if !cues.isEmpty { return cues }
            }
        }
        return []
    }

    /// Build approximate timed cues from plain transcript when no SRT exists.
    static func synthesize(from text: String, duration: TimeInterval) -> [SRTCue] {
        let cleaned = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard duration > 1, cleaned.count > 40 else { return [] }

        var parts = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".\n!?۔"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 12 }
        if parts.count < 4 {
            parts = cleaned
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= 8 }
        }
        guard !parts.isEmpty else { return [] }

        // Weight by character length so longer sentences get more time
        let weights = parts.map { max(Double($0.count), 20) }
        let total = weights.reduce(0, +)
        var cues: [SRTCue] = []
        var t = 0.0
        let pad = min(1.5, duration * 0.01)
        for (i, part) in parts.enumerated() {
            let slice = max(1.2, (weights[i] / total) * max(duration - pad, 1))
            let start = t
            let end = min(duration, t + slice)
            cues.append(SRTCue(id: i, start: start, end: end, text: part))
            t = end
            if t >= duration - 0.05 { break }
        }
        if var last = cues.last, last.end < duration {
            last = SRTCue(id: last.id, start: last.start, end: duration, text: last.text)
            cues[cues.count - 1] = last
        }
        return cues
    }

    static func parse(_ raw: String) -> [SRTCue] {
        // Critical: many Al Qalam SRTs are CRLF — splitting on "\n\n" alone yields ONE block.
        var text = raw.replacingOccurrences(of: "\u{FEFF}", with: "")
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")

        let blocks = text.components(separatedBy: "\n\n")
        var cues: [SRTCue] = []
        var idx = 0
        let timeRe = try! NSRegularExpression(
            pattern: #"(\d{2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{1,3})"#
        )

        for block in blocks {
            let lines = block
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard lines.count >= 2 else { continue }
            let timeLine = lines.first(where: { $0.contains("-->") }) ?? lines[0]
            let ns = timeLine as NSString
            guard let m = timeRe.firstMatch(in: timeLine, range: NSRange(location: 0, length: ns.length)) else {
                continue
            }
            func stamp(_ h: Int, _ mi: Int, _ s: Int, _ frac: Int) -> TimeInterval {
                let fracStr = ns.substring(with: m.range(at: frac))
                let millis: Double
                switch fracStr.count {
                case 1: millis = (Double(fracStr) ?? 0) / 10
                case 2: millis = (Double(fracStr) ?? 0) / 100
                default: millis = (Double(fracStr) ?? 0) / 1000
                }
                let hours = Double(ns.substring(with: m.range(at: h))) ?? 0
                let mins = Double(ns.substring(with: m.range(at: mi))) ?? 0
                let secs = Double(ns.substring(with: m.range(at: s))) ?? 0
                return hours * 3600 + mins * 60 + secs + millis
            }
            let start = stamp(1, 2, 3, 4)
            var end = stamp(5, 6, 7, 8)
            if end <= start { end = start + 1.5 }

            let bodyLines = lines.filter { line in
                if line.contains("-->") { return false }
                // cue index line
                if Int(line) != nil { return false }
                return true
            }
            let body = bodyLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            cues.append(SRTCue(id: idx, start: start, end: end, text: body))
            idx += 1
        }

        // Sort + fix overlaps
        cues.sort { $0.start < $1.start }
        for i in 0 ..< cues.count {
            if i + 1 < cues.count, cues[i].end > cues[i + 1].start {
                let fixed = SRTCue(
                    id: cues[i].id,
                    start: cues[i].start,
                    end: cues[i + 1].start,
                    text: cues[i].text
                )
                cues[i] = fixed
            }
        }
        return cues
    }

    /// When SRT was timed for a longer master (leading silence) but the MP3 is trimmed,
    /// shift cues so the first line lands near t=0. Example: Abu Bakr #1 starts at 1:46 in SRT
    /// while archive.org audio is already content.
    ///
    /// Important: do NOT shift when the audio is the full master (last cue ends before/at
    /// audio end). Late first cues then mean real opening silence — common for Seerah intros.
    static func alignToAudioDuration(_ cues: [SRTCue], audioDuration: TimeInterval) -> (cues: [SRTCue], offsetApplied: TimeInterval) {
        guard cues.count >= 5, audioDuration > 30 else { return (cues, 0) }
        let first = cues[0].start
        let last = cues[cues.count - 1].end
        guard first >= 15 else { return (cues, 0) }

        // Only treat as trimmed when SRT clearly overruns the audio file.
        guard last > audioDuration + 20 else { return (cues, 0) }

        let contentSpan = last - first
        let looksTrimmed =
            abs(contentSpan - audioDuration) < max(90, audioDuration * 0.12)
            || abs((last - first) - audioDuration) < abs(last - audioDuration)

        guard looksTrimmed else { return (cues, 0) }

        var offset = -first
        let endAfter = last + offset
        if endAfter > audioDuration + 45 {
            offset = audioDuration - last
        }
        if first + offset < -1 {
            offset = -first
        }

        let shifted: [SRTCue] = cues.enumerated().map { i, c in
            SRTCue(
                id: i,
                start: max(0, c.start + offset),
                end: max(max(0, c.start + offset) + 0.3, c.end + offset),
                text: c.text
            )
        }
        return (shifted, offset)
    }

    /// Strict window — never sticky leftover text between cues.
    static func activeCue(in cues: [SRTCue], at time: TimeInterval) -> SRTCue? {
        guard !cues.isEmpty, time.isFinite else { return nil }
        // Binary search for cue whose start <= time
        var lo = 0
        var hi = cues.count - 1
        var candidate: Int?
        while lo <= hi {
            let mid = (lo + hi) / 2
            if cues[mid].start <= time {
                candidate = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        guard let i = candidate else { return nil }
        let cue = cues[i]
        if time >= cue.start && time < cue.end { return cue }
        return nil
    }

    static func isPrimarilyRTL(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.prefix(80)
        var rtl = 0
        var ltr = 0
        for s in scalars {
            if (0x0600 ... 0x06FF).contains(s.value)
                || (0x0750 ... 0x077F).contains(s.value)
                || (0xFB50 ... 0xFDFF).contains(s.value)
                || (0xFE70 ... 0xFEFF).contains(s.value) {
                rtl += 1
            } else if (0x0041 ... 0x007A).contains(s.value) || (0x00C0 ... 0x024F).contains(s.value) {
                ltr += 1
            }
        }
        return rtl > ltr
    }
}
