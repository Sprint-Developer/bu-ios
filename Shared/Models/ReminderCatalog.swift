import Foundation

struct ReminderSeed {
    enum Kind {
        case quran(key: String)
        case hadith(book: String, section: Int, number: Int)
        case scholar(id: String)
        case dhikr(id: String)
    }
    let kind: Kind
    let theme: String
    let title: String
}

enum ReminderLane: String, CaseIterable, Identifiable {
    case quran = "Qur’an"
    case hadith = "Hadith"
    case series = "Series"
    case quotes = "Quotes"
    case dhikr = "Dhikr"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .quran: return "book.fill"
        case .hadith: return "text.book.closed.fill"
        case .series: return "waveform.and.mic"
        case .quotes: return "quote.bubble.fill"
        case .dhikr: return "hands.sparkles.fill"
        }
    }
}

enum ReminderCatalog {
    static let themes = ["All", "Qur’an", "Hadith", "Scholars", "Hope", "Patience", "Gratitude", "Trust", "Heart", "Mercy", "Morning"]

    /// Curated, well-known ayahs & hadith — not random noise from the whole corpus.
    static let seeds: [ReminderSeed] = [
        // Qur’an
        .init(kind: .quran(key: "2:255"), theme: "Heart", title: "Ayat al-Kursi"),
        .init(kind: .quran(key: "2:286"), theme: "Mercy", title: "Allah does not burden"),
        .init(kind: .quran(key: "2:152"), theme: "Gratitude", title: "Remember Me"),
        .init(kind: .quran(key: "2:153"), theme: "Patience", title: "Seek help in patience"),
        .init(kind: .quran(key: "3:139"), theme: "Hope", title: "Do not weaken"),
        .init(kind: .quran(key: "3:159"), theme: "Mercy", title: "By mercy from Allah"),
        .init(kind: .quran(key: "9:51"), theme: "Trust", title: "Nothing will befall us"),
        .init(kind: .quran(key: "13:28"), theme: "Heart", title: "Hearts find rest"),
        .init(kind: .quran(key: "14:7"), theme: "Gratitude", title: "If you are grateful"),
        .init(kind: .quran(key: "18:10"), theme: "Trust", title: "Grant us mercy"),
        .init(kind: .quran(key: "21:87"), theme: "Mercy", title: "La ilaha illa Anta"),
        .init(kind: .quran(key: "39:53"), theme: "Hope", title: "Do not despair"),
        .init(kind: .quran(key: "48:1"), theme: "Hope", title: "Clear opening"),
        .init(kind: .quran(key: "55:13"), theme: "Gratitude", title: "Which favors"),
        .init(kind: .quran(key: "65:3"), theme: "Trust", title: "He will provide"),
        .init(kind: .quran(key: "67:2"), theme: "Heart", title: "Who created death"),
        .init(kind: .quran(key: "93:5"), theme: "Hope", title: "Your Lord will give"),
        .init(kind: .quran(key: "94:5"), theme: "Patience", title: "With hardship ease"),
        .init(kind: .quran(key: "94:6"), theme: "Patience", title: "With hardship ease"),
        .init(kind: .quran(key: "94:8"), theme: "Morning", title: "To your Lord turn"),
        .init(kind: .quran(key: "1:5"), theme: "Morning", title: "You alone we worship"),
        .init(kind: .quran(key: "1:6"), theme: "Morning", title: "Guide us"),
        .init(kind: .quran(key: "112:1"), theme: "Heart", title: "He is One"),
        .init(kind: .quran(key: "113:1"), theme: "Morning", title: "Seek refuge"),
        .init(kind: .quran(key: "114:1"), theme: "Morning", title: "Lord of mankind"),

        // Hadith — prefer section 1 entries that reliably exist in the API
        .init(kind: .hadith(book: "bukhari", section: 1, number: 1), theme: "Heart", title: "Actions by intentions"),
        .init(kind: .hadith(book: "bukhari", section: 2, number: 8), theme: "Mercy", title: "Religion is naseehah"),
        .init(kind: .hadith(book: "muslim", section: 1, number: 8), theme: "Heart", title: "Islam · Iman · Ihsan"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 1), theme: "Heart", title: "Actions by intention"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 2), theme: "Heart", title: "Angel Jibreel"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 5), theme: "Heart", title: "Innovation rejected"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 6), theme: "Heart", title: "Halal & haram clear"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 12), theme: "Mercy", title: "Love for brother"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 15), theme: "Mercy", title: "Speak good or silence"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 18), theme: "Trust", title: "Fear Allah wherever"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 19), theme: "Trust", title: "Be mindful of Allah"),
        .init(kind: .hadith(book: "nawawi", section: 1, number: 40), theme: "Hope", title: "Be in the world"),
        .init(kind: .hadith(book: "qudsi", section: 1, number: 1), theme: "Mercy", title: "Hadith Qudsi"),
        .init(kind: .hadith(book: "tirmidhi", section: 1, number: 1), theme: "Morning", title: "Tirmidhi opening"),
    ] + ScholarQuotes.all.map {
        ReminderSeed(kind: .scholar(id: $0.id), theme: $0.theme, title: $0.title)
    } + HisnAlMuslim.allDuas.map {
        ReminderSeed(kind: .dhikr(id: $0.id), theme: "Dhikr", title: HisnAlMuslim.category(id: $0.categoryId)?.titleEn ?? "Dhikr")
    }

    static func seeds(theme: String) -> [ReminderSeed] {
        switch theme {
        case "All":
            return seeds
        case "Qur’an":
            return seeds.filter {
                if case .quran = $0.kind { return true }
                return false
            }
        case "Hadith":
            return seeds.filter {
                if case .hadith = $0.kind { return true }
                return false
            }
        case "Scholars":
            return seeds.filter {
                if case .scholar = $0.kind { return true }
                return false
            }
        case "Dhikr":
            return seeds.filter {
                if case .dhikr = $0.kind { return true }
                return false
            }
        default:
            return seeds.filter { $0.theme == theme }
        }
    }

    static func seeds(lane: ReminderLane) -> [ReminderSeed] {
        switch lane {
        case .quran: return seeds(theme: "Qur’an")
        case .hadith: return seeds(theme: "Hadith")
        case .series: return [] // loaded by SeriesReminderBrain
        case .quotes: return seeds(theme: "Scholars")
        case .dhikr: return seeds(theme: "Dhikr")
        }
    }

    /// Prefer seeds matching the day’s mood, then shuffle within that preference.
    static func smartPool(lane: ReminderLane) -> [ReminderSeed] {
        let all = seeds(lane: lane)
        guard !all.isEmpty else { return [] }
        let mood = SeriesReminderBrain.moodThemes()
        let preferred = all.filter { mood.contains($0.theme) }.shuffled()
        let rest = all.filter { !mood.contains($0.theme) }.shuffled()
        return preferred + rest
    }
}
