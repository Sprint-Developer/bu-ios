import Foundation

/// Picks short, reminder-worthy snippets from Al Qalam / library series.
/// Skips lecture openers (Bismillah / hamdalah / “we ask Allah…”) and prefers body insight.
enum SeriesReminderBrain {
    private static let anwarPrefix = "anwar-"

    /// Themes that feel natural for the current part of the day.
    static func moodThemes(at date: Date = .now) -> [String] {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4 ..< 11:
            return ["Morning", "Gratitude", "Hope", "Trust", "Heart"]
        case 11 ..< 16:
            return ["Heart", "Patience", "Mercy", "Trust"]
        case 16 ..< 20:
            return ["Trust", "Hope", "Patience", "Mercy"]
        default:
            return ["Heart", "Mercy", "Hope", "Dhikr", "Patience"]
        }
    }

    /// Soft keyword weights for “worth remembering” English prose.
    private static let keywordWeights: [(String, Int)] = [
        ("intention", 4), ("niyyah", 4), ("patience", 4), ("sabr", 4),
        ("mercy", 3), ("rahmah", 3), ("tawakkul", 4), ("trust in allah", 4),
        ("heart", 2), ("iman", 3), ("taqwa", 4), ("paradise", 3), ("jannah", 3),
        ("hardship", 3), ("ease", 2), ("grateful", 3), ("shukr", 3),
        ("prophet", 2), ("messenger", 2), ("sahaba", 2), ("companion", 2),
        ("salah", 2), ("quran", 2), ("forgive", 3), ("repent", 3),
        ("akhirah", 3), ("hereafter", 3), ("sincerity", 3), ("ikhlas", 3),
        ("ummah", 1), ("brother", 1), ("love for", 2), ("do not despair", 4),
        ("allah does not", 3), ("for the sake of allah", 4), ("purely for", 3)
    ]

    private static let englishIntroPenalties: [String] = [
        "we ask allah", "in sha allah", "assalamu", "bismillah",
        "the life of muhammad", "yesterday we talked", "tonight we will",
        "tonight we'll", "in this session", "welcome back", "as we mentioned",
        "we covered that", "volume 1", "volume 2", "by imam anwar",
        "al-awlaki", "al awlaki", "we'll start with", "we will start",
        "the next important event", "part 1", "part 2", "chapter 11",
        "do you hear my appeal", "glad tiding to my nation"
    ]

    /// Arabic lines that are almost always lecture openers — never use as reminders.
    private static let arabicIntroMarkers: [String] = [
        "أعوذ", "اعوذ", "اَعُوْذُ", "بسم الله", "بِسْمِ",
        "الحمد لله", "اَلْحَمْدُ", "والصلاة والسلام", "وَالصَّلَاةُ",
        "رب اشرح", "رَبِّ اشْرَح", "يسر لي أمري", "يَسِّرْ لِي",
        "واحلل عقدة", "يفقهوا قولي", "آمين", "امین"
    ]

    /// Build one smart series reminder, or nil if content is unavailable.
    static func pick(avoiding recent: [String]) async -> ReminderItem? {
        let mood = moodThemes()

        // When the user has reading progress, try those chapters first so Home’s series lane
        // is never empty while lecture JSON is still loading or scoring is picky.
        let inProgress = await MainActor.run { inProgressChapterRefs() }
        for chapter in inProgress {
            let refKey = "\(chapter.seriesID)/\(chapter.chapterID)"
            if recent.contains(refKey) { continue }
            guard let body = try? await LibraryContentService.shared.loadChapter(
                seriesID: chapter.seriesID,
                chapterID: chapter.chapterID
            ) else { continue }
            if let item = makeItem(series: chapter, body: body, mood: mood, relax: true) {
                return item
            }
        }

        var candidates = chapterCandidates()
        if candidates.isEmpty, !inProgress.isEmpty {
            candidates = inProgress
        }
        guard !candidates.isEmpty else {
            return await reminderFromProgress(avoiding: recent, mood: mood)
        }

        let context = await MainActor.run { RankContext(mood: mood, recent: recent) }

        // Pre-shuffle so equal scores come out in a different order each refresh,
        // then score once per chapter — the old comparator re-scored (and re-read
        // UserDefaults) on every comparison.
        let shuffled = candidates.shuffled()
        let ranked = shuffled
            .map { (score: scoreChapter($0, context: context), chapter: $0) }
            .sorted { $0.score > $1.score }
            .map { $0.chapter }

        for chapter in ranked.prefix(36) {
            let refKey = "\(chapter.seriesID)/\(chapter.chapterID)"
            if recent.contains(refKey) { continue }
            guard let body = try? await LibraryContentService.shared.loadChapter(
                seriesID: chapter.seriesID,
                chapterID: chapter.chapterID
            ) else { continue }
            if let item = makeItem(series: chapter, body: body, mood: mood) {
                return item
            }
        }

        for chapter in shuffled.prefix(20) {
            guard let body = try? await LibraryContentService.shared.loadChapter(
                seriesID: chapter.seriesID,
                chapterID: chapter.chapterID
            ) else { continue }
            if let item = makeItem(series: chapter, body: body, mood: mood, relax: true) {
                return item
            }
        }
        return await reminderFromProgress(avoiding: recent, mood: mood)
    }

    /// Lightweight reminder tied to the chapter you're actively reading (no JSON snippet required).
    static func reminderFromProgress(avoiding recent: [String], mood: [String]? = nil) async -> ReminderItem? {
        let themes = mood ?? moodThemes()
        let refs = await MainActor.run { inProgressChapterRefs() }
        for chapter in refs {
            let refKey = "\(chapter.seriesID)/\(chapter.chapterID)"
            if recent.contains(refKey) { continue }
            let cleanTitle = chapter.chapterTitle
                .replacingOccurrences(of: #"^#?\d+\.\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return ReminderItem(
                kind: "Series",
                arabic: "",
                english: "Pick up where you left off in “\(cleanTitle.isEmpty ? chapter.seriesTitle : cleanTitle)” — open Library to continue.",
                urdu: "",
                ref: "\(chapter.seriesTitle) · \(cleanTitle.isEmpty ? "Continue" : cleanTitle)",
                theme: themes.first ?? "Heart",
                title: cleanTitle.isEmpty ? chapter.seriesTitle : cleanTitle,
                librarySeriesID: chapter.seriesID,
                libraryChapterID: chapter.chapterID
            )
        }
        return nil
    }

    @MainActor
    private static func inProgressChapterRefs() -> [ChapterRef] {
        let store = LibraryProgressStore.shared
        var out: [ChapterRef] = []
        for series in LibraryCatalog.all {
            guard store.lastChapter[series.id] != nil else { continue }
            guard let chapters = series.chapters, !chapters.isEmpty else { continue }
            guard let ch = store.resumeChapter(in: series) ?? store.nextChapter(in: series) else { continue }
            out.append(ChapterRef(
                seriesID: series.id,
                seriesTitle: series.title,
                chapterID: ch.id,
                chapterTitle: ch.title,
                group: ch.group
            ))
        }
        out.sort {
            let a = store.lastTouchedAt[$0.seriesID] ?? .distantPast
            let b = store.lastTouchedAt[$1.seriesID] ?? .distantPast
            return a > b
        }
        return out
    }

    // MARK: - Ranking

    /// Everything ranking needs, read once instead of per comparison.
    private struct RankContext {
        let mood: [String]
        let recent: Set<String>
        let lastChapter: [String: String]
        let completed: [String: Set<String>]
        /// seriesID → the chapter the reader is heading into next.
        let nextChapter: [String: String]
        let filter: String
        let hour: Int

        @MainActor
        init(mood: [String], recent: [String]) {
            let store = LibraryProgressStore.shared
            self.mood = mood.map { $0.lowercased() }
            self.recent = Set(recent)
            lastChapter = store.lastChapter
            completed = store.completed
            var next: [String: String] = [:]
            for series in LibraryCatalog.all where store.lastChapter[series.id] != nil {
                if let n = store.nextChapter(in: series) { next[series.id] = n.id }
            }
            nextChapter = next
            filter = UserDefaults.standard.string(forKey: "beummati.series.reminderFilter") ?? "all"
            hour = Calendar.current.component(.hour, from: .now)
        }
    }

    private struct ChapterRef {
        let seriesID: String
        let seriesTitle: String
        let chapterID: String
        let chapterTitle: String
        let group: String?
    }

    private static func chapterCandidates() -> [ChapterRef] {
        var out: [ChapterRef] = []
        for series in LibraryCatalog.all where series.id.hasPrefix(anwarPrefix) || series.kind == .chapters {
            guard let chapters = series.chapters, !chapters.isEmpty else { continue }
            // Skip obvious intro episodes when possible (aq-01 / Introduction)
            for ch in chapters {
                let titleLow = ch.title.lowercased()
                let isIntroEpisode =
                    ch.id.hasSuffix("-01") || ch.id == "aq-01"
                    || titleLow.contains("introduction") || titleLow.contains("intro ")
                if isIntroEpisode { continue }
                out.append(ChapterRef(
                    seriesID: series.id,
                    seriesTitle: series.title,
                    chapterID: ch.id,
                    chapterTitle: ch.title,
                    group: ch.group
                ))
            }
        }
        // If everything was filtered, fall back to full list
        if out.isEmpty {
            for series in LibraryCatalog.all where series.id.hasPrefix(anwarPrefix) {
                for ch in series.chapters ?? [] {
                    out.append(ChapterRef(
                        seriesID: series.id,
                        seriesTitle: series.title,
                        chapterID: ch.id,
                        chapterTitle: ch.title,
                        group: ch.group
                    ))
                }
            }
        }
        return out
    }

    private static func scoreChapter(_ ch: ChapterRef, context: RankContext) -> Int {
        var score = 0
        let refKey = "\(ch.seriesID)/\(ch.chapterID)"
        if context.recent.contains(refKey) { score -= 40 }
        // Lean hard toward series you're actually working through, and inside those
        // toward the chapter you're on / about to open.
        if context.lastChapter[ch.seriesID] != nil { score += 18 }
        if context.lastChapter[ch.seriesID] == ch.chapterID { score += 10 }
        if context.nextChapter[ch.seriesID] == ch.chapterID { score += 26 }
        if context.completed[ch.seriesID]?.contains(ch.chapterID) == true { score -= 6 }

        switch context.filter {
        case "seerah":
            score += ch.seriesID.contains("seerah") ? 25 : -30
        case "prophets":
            score += ch.seriesID.contains("prophets") ? 25 : -30
        case "abu-bakr":
            score += ch.seriesID.contains("abu-bakr") ? 25 : -30
        case "umar":
            score += ch.seriesID.contains("umar") ? 25 : -30
        default:
            break
        }

        let blob = "\(ch.seriesTitle) \(ch.chapterTitle) \(ch.group ?? "")".lowercased()
        for theme in context.mood where blob.contains(theme) {
            score += 4
        }
        let hour = context.hour
        if hour < 11, ch.seriesID.contains("seerah") || ch.seriesID.contains("prophets") { score += 2 }
        if hour >= 20, ch.seriesID.contains("hereafter") || ch.seriesID.contains("dreams") { score += 3 }
        if ch.seriesID.contains("abu-bakr") || ch.seriesID.contains("umar") { score += 1 }
        return score
    }

    // MARK: - Snippet extraction

    private static func makeItem(
        series: ChapterRef,
        body: LibraryChapterBody,
        mood: [String],
        relax: Bool = false
    ) -> ReminderItem? {
        let english = pickEnglishSnippet(from: body.english, mood: mood, relax: relax)
        guard let english, !english.isEmpty else { return nil }

        let urdu = pickUrduSnippet(from: body.urdu, mood: mood)
        // Only attach Arabic when we found a non-intro ayah/quote — never the opening hamdalah.
        let arabic = pickArabicSnippet(from: body.arabic)

        let cleanTitle = series.chapterTitle
            .replacingOccurrences(of: #"^#?\d+\.\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ReminderItem(
            kind: "Series",
            arabic: arabic,
            english: english,
            urdu: urdu,
            ref: "\(series.seriesTitle) · \(cleanTitle)",
            theme: mood.first ?? "Heart",
            title: cleanTitle.isEmpty ? series.seriesTitle : cleanTitle,
            librarySeriesID: series.seriesID,
            libraryChapterID: series.chapterID
        )
    }

    private static func pickEnglishSnippet(from text: String, mood: [String], relax: Bool) -> String? {
        let paragraphs = englishParagraphs(from: text)
        guard !paragraphs.isEmpty else { return nil }

        let minLen = relax ? 55 : 90
        let maxLen = relax ? 480 : 360

        // Drop the opening chunk of the lecture (intros / recap)
        let skip = min(max(paragraphs.count / 5, 2), paragraphs.count - 1)
        let bodyPool = Array(paragraphs.dropFirst(skip))
        let pools = [bodyPool, paragraphs] // body first, full as fallback

        for (poolIndex, pool) in pools.enumerated() {
            var scored: [(Int, String)] = []
            for (i, p) in pool.enumerated() {
                let t = tidySnippet(p)
                guard t.count >= minLen, t.count <= maxLen else { continue }
                var s = scoreEnglish(t, mood: mood)
                // Prefer later material in the pool
                if poolIndex == 0 { s += 3 }
                if i > pool.count / 3 { s += 1 }
                scored.append((s, t))
            }
            scored.sort { $0.0 > $1.0 }
            let threshold = relax ? -2 : 2
            if let best = scored.first, best.0 >= threshold {
                return best.1
            }
        }

        // Last resort: first mid-length non-intro paragraph
        return paragraphs
            .dropFirst(min(2, max(0, paragraphs.count - 1)))
            .map(tidySnippet)
            .first { t in
                t.count >= minLen && t.count <= maxLen && !isEnglishIntro(t)
            }
    }

    private static func englishParagraphs(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lines = trimmed
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var paragraphs: [String] = []
        var buf = ""
        for line in lines {
            if buf.isEmpty {
                buf = line
            } else if buf.count + line.count < 340 {
                buf += " " + line
            } else {
                paragraphs.append(buf)
                buf = line
            }
        }
        if !buf.isEmpty { paragraphs.append(buf) }

        // Also add clean sentence bites from long paragraphs
        var extras: [String] = []
        for p in paragraphs where p.count > 220 {
            let sentences = p
                .components(separatedBy: CharacterSet(charactersIn: ".!?"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { (90 ... 320).contains($0.count) }
            extras.append(contentsOf: sentences)
        }
        return paragraphs + extras
    }

    private static func scoreEnglish(_ text: String, mood: [String]) -> Int {
        let low = text.lowercased()
        var score = 0
        for (word, w) in keywordWeights where low.contains(word) {
            score += w
        }
        for theme in mood where low.contains(theme.lowercased()) {
            score += 2
        }
        if isEnglishIntro(text) { score -= 12 }
        for pen in englishIntroPenalties where low.contains(pen) {
            score -= 5
        }
        if (110 ... 280).contains(text.count) { score += 3 }
        if text.contains("ﷺ") || text.contains("رضي") { score += 1 }
        // Narrative teaching beats pure chapter headers
        if text.split(separator: " ").count >= 14 { score += 1 }
        if low.hasPrefix("chapter ") || low.hasPrefix("part ") { score -= 8 }
        return score
    }

    private static func isEnglishIntro(_ text: String) -> Bool {
        let low = text.lowercased()
        if englishIntroPenalties.contains(where: { low.contains($0) }) { return true }
        if low.hasPrefix("the life of") { return true }
        if low.hasPrefix("we ask") { return true }
        if low.hasPrefix("yesterday") { return true }
        return false
    }

    private static func tidySnippet(_ text: String) -> String {
        var t = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > 360 {
            let idx = t.index(t.startIndex, offsetBy: 340)
            if let space = t[..<idx].lastIndex(of: " ") {
                t = String(t[..<space]).trimmingCharacters(in: .whitespaces) + "…"
            } else {
                t = String(t.prefix(340)) + "…"
            }
        }
        return t
    }

    private static func pickUrduSnippet(from text: String, mood: [String]) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        let paras = t
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 50 }

        guard !paras.isEmpty else {
            return t.count <= 280 ? t : String(t.prefix(260)) + "…"
        }

        // Skip opening duas / intros
        let skip = min(max(paras.count / 5, 1), paras.count - 1)
        let body = Array(paras.dropFirst(skip))
        let pool = body.isEmpty ? paras : body

        let introBits = ["اللہ تعالیٰ سے دعا", "ہم اللہ سے", "بسم اللہ", "الحمد للہ"]
        let scored: [(Int, String)] = pool.map { p in
            var s = 0
            let low = p
            for bit in introBits where low.contains(bit) { s -= 6 }
            if (80 ... 280).contains(p.count) { s += 3 }
            if p.count > 40 { s += 1 }
            // Soft mood: Arabic loanwords often appear in teaching lines
            for theme in mood {
                // mood is English; skip
                _ = theme
            }
            return (s, p)
        }
        .sorted { $0.0 > $1.0 }

        if let best = scored.first {
            let p = best.1
            return p.count <= 320 ? p : String(p.prefix(300)) + "…"
        }
        return ""
    }

    /// Prefer a Qur’anic / teaching line from the middle — never Bismillah / hamdalah openers.
    private static func pickArabicSnippet(from arabic: String?) -> String {
        guard let raw = arabic?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return ""
        }

        let lines = raw
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .flatMap { splitArabicRuns($0) }

        guard !lines.isEmpty else { return "" }

        var scored: [(Int, String)] = []
        for (i, line) in lines.enumerated() {
            let cleaned = tidyArabic(line)
            guard cleaned.count >= 24, cleaned.count <= 240 else { continue }
            if isArabicIntro(cleaned) { continue }

            var s = 0
            // Strongly prefer content after the opener block
            if i >= 3 { s += 4 }
            if i >= 5 { s += 2 }
            // Verse markers / ayah-like punctuation
            if cleaned.contains("۝") || cleaned.contains("۞") { s += 6 }
            if cleaned.contains("قال") || cleaned.contains("قَالَ") { s += 3 }
            if cleaned.contains("إنّ") || cleaned.contains("إِنَّ") { s += 2 }
            if cleaned.contains("الله") || cleaned.contains("اللّه") { s += 1 }
            // Penalize pure salawat leftover
            if cleaned.contains("صلى الله") || cleaned.contains("صَلَّاة") { s -= 3 }
            if (40 ... 180).contains(cleaned.count) { s += 3 }
            scored.append((s, cleaned))
        }

        scored.sort { $0.0 > $1.0 }
        // Require a positive score so we never fall back to intro
        if let best = scored.first, best.0 >= 3 {
            return best.1
        }
        // No good body Arabic — leave empty (English reminder still works)
        return ""
    }

    private static func splitArabicRuns(_ line: String) -> [String] {
        // Some files jam multiple ayahs on one line separated by ۝ / ۞
        let parts = line
            .components(separatedBy: CharacterSet(charactersIn: "۝۞"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [line] : parts
    }

    private static func isArabicIntro(_ text: String) -> Bool {
        for marker in arabicIntroMarkers where text.contains(marker) {
            // Short lines that are ONLY the opener
            if text.count < 120 { return true }
            // Longer lines that START with opener
            if text.hasPrefix(marker) || text.prefix(20).contains(marker) { return true }
        }
        // Classic opener combo on one line
        if text.contains("أعوذ") || text.contains("اَعُوْذُ") { return true }
        if text.contains("بِسْمِ") && text.count < 80 { return true }
        if text.contains("اَلْحَمْدُ") && text.contains("وَالصَّلَاةُ") { return true }
        if text.contains("الحمد لله") && text.contains("الصلاة") { return true }
        return false
    }

    private static func tidyArabic(_ text: String) -> String {
        var t = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip leftover Latin glosses sometimes glued on (e.g. "Al")
        t = t.replacingOccurrences(
            of: #"\s+[A-Za-z][A-Za-z\s\.]{0,40}$"#,
            with: "",
            options: .regularExpression
        )
        if t.count > 220 {
            t = String(t.prefix(200)) + "…"
        }
        return t
    }
}
