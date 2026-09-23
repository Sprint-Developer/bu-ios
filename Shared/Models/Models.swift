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
