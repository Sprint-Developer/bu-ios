import Foundation

enum LangShow: String, CaseIterable, Identifiable {
    case arabic = "Arabic"
    case english = "English"
    case urdu = "Urdu"
    var id: String { rawValue }
}

struct ReminderItem: Identifiable, Equatable {
    var id: String { "\(kind)|\(ref)|\(arabic.prefix(24))" }
    let kind: String // Qur’an / Hadith / Scholar / Dhikr / Series
    let arabic: String
    let english: String
    let urdu: String
    let ref: String
    var theme: String = ""
    var title: String = ""
    /// Qur’an verse key e.g. "2:255" — used to open the ayah.
    var quranKey: String? = nil
    /// Hadith edition slug + global number — used to open the hadith.
    var hadithBook: String? = nil
    var hadithNumber: Int? = nil
    /// Hisn al-Muslim dua id.
    var duaID: String? = nil
    /// Scholar profile id for quote reminders.
    var scholarID: String? = nil
    /// Library series chapter (Al Qalam lectures, etc.).
    var librarySeriesID: String? = nil
    var libraryChapterID: String? = nil
}

struct QuranChapter: Identifiable, Hashable {
    let id: Int
    let nameArabic: String
    let nameSimple: String
    let versesCount: Int
    let revelationPlace: String
}

struct QuranAyah: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let arabicUthmani: String
    let arabicIndopak: String
    let english: String
    let urdu: String

    var surah: Int {
        Int(key.split(separator: ":").first.map(String.init) ?? "") ?? 0
    }
    var numberInSurah: Int {
        Int(key.split(separator: ":").last.map(String.init) ?? "") ?? 0
    }

    /// Prefer Indo-Pak script when that font family is selected.
    func arabic(for font: ScriptFont) -> String {
        switch font {
        case .indoPak, .mehrNastaliq, .notoNastaliq, .gulzar:
            return arabicIndopak.isEmpty ? arabicUthmani : arabicIndopak
        default:
            return arabicUthmani.isEmpty ? arabicIndopak : arabicUthmani
        }
    }
}

/// Hafs juz (parah) boundary — mirrors Android `JuzInfo` / `JuzCatalog`.
struct JuzInfo: Identifiable, Hashable {
    var id: Int { number }
    let number: Int
    let startKey: String
    let endKey: String
    let startSurahName: String

    var titleEnglish: String { "Parah \(number)" }
    var titleUrdu: String { "پارہ \(number)" }
    var rangeLabel: String { "\(startKey) – \(endKey)" }
}

enum JuzCatalog {
    static let all: [JuzInfo] = [
        JuzInfo(number: 1, startKey: "1:1", endKey: "2:141", startSurahName: "Al-Fatihah"),
        JuzInfo(number: 2, startKey: "2:142", endKey: "2:252", startSurahName: "Al-Baqarah"),
        JuzInfo(number: 3, startKey: "2:253", endKey: "3:91", startSurahName: "Al-Baqarah"),
        JuzInfo(number: 4, startKey: "3:92", endKey: "4:23", startSurahName: "Aal-E-Imran"),
        JuzInfo(number: 5, startKey: "4:24", endKey: "4:147", startSurahName: "An-Nisa"),
        JuzInfo(number: 6, startKey: "4:148", endKey: "5:81", startSurahName: "An-Nisa"),
        JuzInfo(number: 7, startKey: "5:82", endKey: "6:110", startSurahName: "Al-Ma'idah"),
        JuzInfo(number: 8, startKey: "6:111", endKey: "7:87", startSurahName: "Al-An'am"),
        JuzInfo(number: 9, startKey: "7:88", endKey: "8:40", startSurahName: "Al-A'raf"),
        JuzInfo(number: 10, startKey: "8:41", endKey: "9:92", startSurahName: "Al-Anfal"),
        JuzInfo(number: 11, startKey: "9:93", endKey: "11:5", startSurahName: "At-Tawbah"),
        JuzInfo(number: 12, startKey: "11:6", endKey: "12:52", startSurahName: "Hud"),
        JuzInfo(number: 13, startKey: "12:53", endKey: "14:52", startSurahName: "Yusuf"),
        JuzInfo(number: 14, startKey: "15:1", endKey: "16:128", startSurahName: "Al-Hijr"),
        JuzInfo(number: 15, startKey: "17:1", endKey: "18:74", startSurahName: "Al-Isra"),
        JuzInfo(number: 16, startKey: "18:75", endKey: "20:135", startSurahName: "Al-Kahf"),
        JuzInfo(number: 17, startKey: "21:1", endKey: "22:78", startSurahName: "Al-Anbiya"),
        JuzInfo(number: 18, startKey: "23:1", endKey: "25:20", startSurahName: "Al-Mu'minun"),
        JuzInfo(number: 19, startKey: "25:21", endKey: "27:55", startSurahName: "Al-Furqan"),
        JuzInfo(number: 20, startKey: "27:56", endKey: "29:45", startSurahName: "An-Naml"),
        JuzInfo(number: 21, startKey: "29:46", endKey: "33:30", startSurahName: "Al-Ankabut"),
        JuzInfo(number: 22, startKey: "33:31", endKey: "36:27", startSurahName: "Al-Ahzab"),
        JuzInfo(number: 23, startKey: "36:28", endKey: "39:31", startSurahName: "Ya-Sin"),
        JuzInfo(number: 24, startKey: "39:32", endKey: "41:46", startSurahName: "Az-Zumar"),
        JuzInfo(number: 25, startKey: "41:47", endKey: "45:37", startSurahName: "Fussilat"),
        JuzInfo(number: 26, startKey: "46:1", endKey: "51:30", startSurahName: "Al-Ahqaf"),
        JuzInfo(number: 27, startKey: "51:31", endKey: "57:29", startSurahName: "Adh-Dhariyat"),
        JuzInfo(number: 28, startKey: "58:1", endKey: "66:12", startSurahName: "Al-Mujadila"),
        JuzInfo(number: 29, startKey: "67:1", endKey: "77:50", startSurahName: "Al-Mulk"),
        JuzInfo(number: 30, startKey: "78:1", endKey: "114:6", startSurahName: "An-Naba")
    ]

    static func get(_ number: Int) -> JuzInfo? {
        all.first { $0.number == number }
    }
}

struct HadithBook: Identifiable, Hashable {
    var id: String { slug }
    let slug: String
    let name: String
    let hasUrdu: Bool
}

struct HadithItem: Identifiable, Hashable {
    var id: String { "\(book)-\(number)" }
    let book: String
    let number: Int
    let arabic: String
    let english: String
    let urdu: String
}

struct PrayerDay: Equatable, Codable {
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
    let hijriDate: String
    let hijriWeekday: String
    let gregorian: String
}

struct NoteItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var ref: String
    var tags: [String] = []
    var linkKind: String = "" // Qur’an / Hadith / Reminder / personal
    var created: Date = Date()
}

struct BookmarkItem: Identifiable, Codable, Equatable {
    var id: String { "\(kind)|\(ref)" }
    var kind: String
    var ref: String
    var title: String
    var arabic: String
    var english: String
    var urdu: String
    var created: Date = Date()
}

enum HTMLStrip {
    /// Strip HTML / footnote markers and decode common entities (Quran.com translations).
    static func clean(_ raw: String) -> String {
        cleanTranslation(raw)
    }

    /// Light cleanup for plain Urdu/Arabic prose (tafsir, books) — no digit mangling.
    static func cleanPlain(_ raw: String) -> String {
        var s = raw
        s = s.replacingOccurrences(
            of: #"<br\s*/?>"#,
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        s = s.replacingOccurrences(
            of: #"<sup\b[^>]*>.*?</sup>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        s = s.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        s = decodeEntities(s)
        s = s.replacingOccurrences(of: #"\u{00A0}"#, with: " ")
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Quran.com translation HTML (footnotes + entities).
    static func cleanTranslation(_ raw: String) -> String {
        var s = cleanPlain(raw)
        // Footnote leftovers like "ہیں1،" after <sup> strip
        s = s.replacingOccurrences(
            of: #"([^\d\s])\d{1,2}([،٫۔,:;!?\s])"#,
            with: "$1$2",
            options: .regularExpression
        )
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ input: String) -> String {
        var s = input
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&#39;", with: "'")
        s = s.replacingOccurrences(of: "&apos;", with: "'")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        return decodeNumericEntities(s)
    }

    private static func decodeNumericEntities(_ input: String) -> String {
        var out = input
        let pattern = #"&#(x?[0-9A-Fa-f]+);"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return out }
        let matches = regex.matches(in: out, range: NSRange(out.startIndex..., in: out)).reversed()
        for m in matches {
            guard let full = Range(m.range, in: out),
                  let numRange = Range(m.range(at: 1), in: out) else { continue }
            let token = String(out[numRange])
            let scalar: Unicode.Scalar?
            if token.lowercased().hasPrefix("x") {
                scalar = UInt32(token.dropFirst(), radix: 16).flatMap(Unicode.Scalar.init)
            } else {
                scalar = UInt32(token).flatMap(Unicode.Scalar.init)
            }
            if let scalar {
                out.replaceSubrange(full, with: String(Character(scalar)))
            }
        }
        return out
    }
}
