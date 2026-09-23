import Foundation

struct ScholarProfile: Identifiable, Hashable {
    let id: String
    let name: String
    let era: String
    let blurb: String
    let sortOrder: Int
}

/// A scholar saying — only included when `reference` is non-empty.
struct ScholarQuote: Identifiable, Hashable, Codable {
    var id: String { "\(scholarID)|\(reference)|\(english.prefix(48))" }
    let scholarID: String
    let author: String
    let title: String
    let english: String
    let arabic: String
    let urdu: String
    let reference: String
    let theme: String

    var displayRef: String { "\(author) · \(reference)" }
}

enum ScholarQuotes {
    static let profiles: [ScholarProfile] = [
        .init(id: "abu-hanifa", name: "Imam Abu Hanifa", era: "80–150 AH", blurb: "Founder of the Hanafi school · Kufa", sortOrder: 1),
        .init(id: "malik", name: "Imam Malik", era: "93–179 AH", blurb: "Imam of Dar al-Hijrah · Al-Muwatta", sortOrder: 2),
        .init(id: "shafii", name: "Imam al-Shafi'i", era: "150–204 AH", blurb: "Founder of the Shafi'i school · Usul pioneer", sortOrder: 3),
        .init(id: "ahmad", name: "Imam Ahmad ibn Hanbal", era: "164–241 AH", blurb: "Imam of Ahl al-Hadith · Al-Musnad", sortOrder: 4),
        .init(id: "bukhari", name: "Imam al-Bukhari", era: "194–256 AH", blurb: "Compiler of Sahih al-Bukhari", sortOrder: 5),
        .init(id: "muslim", name: "Imam Muslim", era: "206–261 AH", blurb: "Compiler of Sahih Muslim", sortOrder: 6),
        .init(id: "nawawi", name: "Imam al-Nawawi", era: "631–676 AH", blurb: "Riyad al-Salihin · Forty Hadith · Shafi'i jurist", sortOrder: 7),
        .init(id: "ghazali", name: "Imam al-Ghazali", era: "450–505 AH", blurb: "Ihya Ulum al-Din · Hujjat al-Islam", sortOrder: 8),
        .init(id: "ibn-taymiyyah", name: "Ibn Taymiyyah", era: "661–728 AH", blurb: "Shaykh al-Islam · Majmu' al-Fatawa", sortOrder: 9),
        .init(id: "ibn-al-qayyim", name: "Ibn al-Qayyim", era: "691–751 AH", blurb: "Student of Ibn Taymiyyah · Madarij · I'lam", sortOrder: 10),
        .init(id: "ibn-kathir", name: "Ibn Kathir", era: "701–774 AH", blurb: "Tafsir Ibn Kathir · Al-Bidaya wa al-Nihaya", sortOrder: 11),
        .init(id: "ibn-rajab", name: "Ibn Rajab al-Hanbali", era: "736–795 AH", blurb: "Jami' al-Ulum wa al-Hikam", sortOrder: 12),
        .init(id: "dhahabi", name: "Al-Dhahabi", era: "673–748 AH", blurb: "Siyar A'lam al-Nubala · hadith critic", sortOrder: 13),
        .init(id: "ibn-hajar", name: "Ibn Hajar al-Asqalani", era: "773–852 AH", blurb: "Fath al-Bari · Hady al-Sari", sortOrder: 14)
    ]

    static var catalog: [ScholarProfile] {
        profiles.sorted { $0.sortOrder < $1.sortOrder }
    }

    static func profile(id: String) -> ScholarProfile? {
        profiles.first { $0.id == id }
    }

    static func quotes(for scholarID: String) -> [ScholarQuote] {
        all.filter { $0.scholarID == scholarID }
    }

    static func count(for scholarID: String) -> Int {
        quotes(for: scholarID).count
    }

    /// Loaded from ScholarQuotes.json — referenced sayings only.
    static let all: [ScholarQuote] = load()

    static var authors: [String] { catalog.map(\.name) }

    static func byAuthor(_ author: String) -> [ScholarQuote] {
        all.filter { $0.author == author }
    }

    static func themed(_ theme: String) -> [ScholarQuote] {
        all.filter { $0.theme == theme }
    }

    static func asReminder(_ q: ScholarQuote) -> ReminderItem {
        ReminderItem(
            kind: "Scholar",
            arabic: q.arabic,
            english: q.english,
            urdu: q.urdu,
            ref: q.displayRef,
            theme: q.theme,
            title: "\(q.author) — \(q.title)",
            scholarID: q.scholarID
        )
    }

    private static func load() -> [ScholarQuote] {
        let urls: [URL?] = [
            Bundle.main.url(forResource: "ScholarQuotes", withExtension: "json"),
            Bundle.main.url(forResource: "ScholarQuotes", withExtension: "json", subdirectory: "Resources")
        ]
        for url in urls.compactMap({ $0 }) {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([ScholarQuote].self, from: data) {
                return decoded.filter {
                    !$0.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }
        }
        return []
    }
}
