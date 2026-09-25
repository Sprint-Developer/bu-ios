import Foundation
import Combine

/// Spaced-repetition intervals after a successful review (days). Matches Android HifzStore.
private let hifzReviewIntervals = [1, 3, 7, 14, 30]

struct AyahReviewEntry: Codable, Equatable {
    var stage: Int = 0
    /// ISO date when due next; empty = not scheduled.
    var nextDue: String = ""
}

struct HifzSnapshot: Codable, Equatable {
    var memorized: Set<String> = []
    var weak: Set<String> = []
    var reviews: [String: AyahReviewEntry] = [:]
    var activityDays: Set<String> = []
    var dailyGoal: Int = 5
    var markedToday: [String: Int] = [:]
}

struct HifzStats: Equatable {
    var memorizedCount: Int = 0
    var weakCount: Int = 0
    var dueTodayCount: Int = 0
    var reviewedThisWeek: Int = 0
    var streakDays: Int = 0
    var dailyGoal: Int = 5
    var markedTodayCount: Int = 0
}

enum HifzQuizMode: String, CaseIterable, Identifiable {
    case hideArabic
    case audioOnly
    case showArabic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hideArabic: return "Hide Arabic"
        case .audioOnly: return "Audio only"
        case .showArabic: return "Show Arabic"
        }
    }

    var blurb: String {
        switch self {
        case .hideArabic: return "Recall the ayah, then reveal"
        case .audioOnly: return "Listen, then reveal text"
        case .showArabic: return "Translation recall"
        }
    }
}

/// Memorization progress with gentle spaced repetition — mirrors Android `HifzStore`.
@MainActor
final class HifzStore: ObservableObject {
    static let shared = HifzStore()

    @Published private(set) var memorized: Set<String> = []
    @Published private(set) var weakKeys: Set<String> = []
    @Published private(set) var dueToday: [String] = []
    @Published private(set) var stats = HifzStats()
    @Published var quizMode: HifzQuizMode = .hideArabic {
        didSet { defaults.set(quizMode.rawValue, forKey: Keys.quizMode) }
    }

    private var reviews: [String: AyahReviewEntry] = [:]
    private var activityDays: Set<String> = []
    private var dailyGoal: Int = 5
    private var markedToday: [String: Int] = [:]

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let snapshot = "beummati.hifz.snapshot.v1"
        static let quizMode = "beummati.hifz.quizMode"
        static let firstHint = "beummati.hifz.firstHintShown"
    }

    private init() {
        if let raw = defaults.string(forKey: Keys.quizMode),
           let mode = HifzQuizMode(rawValue: raw) {
            quizMode = mode
        }
        load()
    }

    func reload() { load() }

    func exportSnapshotJSON() -> String {
        (try? String(data: JSONEncoder().encode(currentSnapshot()), encoding: .utf8)) ?? "{}"
    }

    func importSnapshotJSON(_ json: String) {
        guard let data = json.data(using: .utf8),
              let snap = try? JSONDecoder().decode(HifzSnapshot.self, from: data) else { return }
        apply(snap)
        persist()
    }

    func setDailyGoal(_ goal: Int) {
        dailyGoal = min(50, max(1, goal))
        persist()
        refreshDerived()
    }

    func markMemorized(_ key: String) {
        guard !key.isEmpty else { return }
        let wasNew = !memorized.contains(key)
        memorized.insert(key)
        weakKeys.remove(key)
        let today = Self.todayISO()
        reviews[key] = AyahReviewEntry(
            stage: 0,
            nextDue: Self.iso(daysFromToday: hifzReviewIntervals[0])
        )
        if wasNew { bumpMarkedToday(today) }
        noteActivity(today)
        persist()
        refreshDerived()
    }

    func unmark(_ key: String) {
        guard !key.isEmpty else { return }
        memorized.remove(key)
        weakKeys.remove(key)
        reviews.removeValue(forKey: key)
        persist()
        refreshDerived()
    }

    func flagWeak(_ key: String) {
        guard memorized.contains(key) else { return }
        weakKeys.insert(key)
        reviews[key] = AyahReviewEntry(stage: 0, nextDue: Self.iso(daysFromToday: 1))
        persist()
        refreshDerived()
    }

    func markSurahMemorized(surah: Int, ayahCount: Int) {
        guard (1...114).contains(surah), ayahCount > 0 else { return }
        let today = Self.todayISO()
        let next = Self.iso(daysFromToday: hifzReviewIntervals[0])
        var added = 0
        for n in 1...ayahCount {
            let key = "\(surah):\(n)"
            if !memorized.contains(key) {
                memorized.insert(key)
                added += 1
            }
            reviews[key] = AyahReviewEntry(stage: 0, nextDue: next)
            weakKeys.remove(key)
        }
        if added > 0 {
            markedToday[today, default: 0] += added
            noteActivity(today)
        }
        persist()
        refreshDerived()
    }

    func unmarkSurah(_ surah: Int) {
        let prefix = "\(surah):"
        let drop = memorized.filter { $0.hasPrefix(prefix) }
        guard !drop.isEmpty else { return }
        memorized.subtract(drop)
        weakKeys.subtract(drop)
        drop.forEach { reviews.removeValue(forKey: $0) }
        persist()
        refreshDerived()
    }

    func recordReview(key: String, remembered: Bool) {
        guard !key.isEmpty else { return }
        if !memorized.contains(key) {
            if remembered { markMemorized(key) }
            return
        }
        let today = Self.todayISO()
        let current = reviews[key] ?? AyahReviewEntry()
        if remembered {
            weakKeys.remove(key)
            let stage = min(current.stage + 1, hifzReviewIntervals.count - 1)
            reviews[key] = AyahReviewEntry(
                stage: stage,
                nextDue: Self.iso(daysFromToday: hifzReviewIntervals[stage])
            )
        } else {
            weakKeys.insert(key)
            reviews[key] = AyahReviewEntry(stage: 0, nextDue: Self.iso(daysFromToday: 1))
        }
        noteActivity(today)
        persist()
        refreshDerived()
    }

    func isMemorized(_ key: String) -> Bool { memorized.contains(key) }
    func isWeak(_ key: String) -> Bool { weakKeys.contains(key) }

    func memorizedInSurah(_ number: Int) -> Int {
        memorized.filter { $0.hasPrefix("\(number):") }.count
    }

    func progressForSurah(_ number: Int, ayahCount: Int) -> Float {
        guard ayahCount > 0 else { return 0 }
        return Float(memorizedInSurah(number)) / Float(ayahCount)
    }

    /// True the first time the user marks an ayah.
    func consumeFirstMemorizeHint() -> Bool {
        if defaults.bool(forKey: Keys.firstHint) { return false }
        defaults.set(true, forKey: Keys.firstHint)
        return true
    }

    // MARK: - Private

    private func load() {
        guard let data = defaults.data(forKey: Keys.snapshot),
              let snap = try? JSONDecoder().decode(HifzSnapshot.self, from: data) else {
            apply(HifzSnapshot())
            return
        }
        apply(snap)
    }

    private func apply(_ snap: HifzSnapshot) {
        memorized = snap.memorized
        weakKeys = snap.weak
        reviews = snap.reviews
        activityDays = snap.activityDays
        dailyGoal = min(50, max(1, snap.dailyGoal))
        markedToday = snap.markedToday
        refreshDerived()
    }

    private func currentSnapshot() -> HifzSnapshot {
        HifzSnapshot(
            memorized: memorized,
            weak: weakKeys,
            reviews: reviews,
            activityDays: activityDays,
            dailyGoal: dailyGoal,
            markedToday: markedToday
        )
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(currentSnapshot()) {
            defaults.set(data, forKey: Keys.snapshot)
        }
    }

    private func bumpMarkedToday(_ today: String) {
        markedToday[today, default: 0] += 1
    }

    private func noteActivity(_ today: String) {
        activityDays.insert(today)
    }

    private func dueForReview(today: Date = Date()) -> [String] {
        let todayISO = Self.isoString(today)
        var due = Set<String>()
        for key in weakKeys where memorized.contains(key) { due.insert(key) }
        for key in memorized {
            let dueDate = reviews[key]?.nextDue ?? ""
            if dueDate.isEmpty || dueDate <= todayISO { due.insert(key) }
        }
        return due.sorted {
            let a = $0.split(separator: ":").compactMap { Int($0) }
            let b = $1.split(separator: ":").compactMap { Int($0) }
            if (a.first ?? 0) != (b.first ?? 0) { return (a.first ?? 0) < (b.first ?? 0) }
            return (a.dropFirst().first ?? 0) < (b.dropFirst().first ?? 0)
        }
    }

    private func streakDays(today: Date = Date()) -> Int {
        var streak = 0
        var cursor = today
        let cal = Calendar.current
        if !activityDays.contains(Self.isoString(today)) {
            cursor = cal.date(byAdding: .day, value: -1, to: today) ?? today
        }
        while activityDays.contains(Self.isoString(cursor)) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private func reviewedThisWeek(today: Date = Date()) -> Int {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -6, to: today) else { return 0 }
        let startISO = Self.isoString(start)
        let todayISO = Self.isoString(today)
        return activityDays.filter { $0 >= startISO && $0 <= todayISO }.count
    }

    private func refreshDerived() {
        let due = dueForReview()
        dueToday = due
        let today = Self.todayISO()
        stats = HifzStats(
            memorizedCount: memorized.count,
            weakCount: weakKeys.count,
            dueTodayCount: due.count,
            reviewedThisWeek: reviewedThisWeek(),
            streakDays: streakDays(),
            dailyGoal: dailyGoal,
            markedTodayCount: markedToday[today] ?? 0
        )
    }

    private static func todayISO() -> String { isoString(Date()) }

    private static func isoString(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private static func iso(daysFromToday: Int) -> String {
        let cal = Calendar.current
        let d = cal.date(byAdding: .day, value: daysFromToday, to: Date()) ?? Date()
        return isoString(d)
    }
}
