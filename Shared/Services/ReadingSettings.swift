import SwiftUI
import Combine
import UIKit

enum AppReadingLanguage: String, CaseIterable, Identifiable {
    case allThree = "Arabic + English + Urdu"
    case englishFocus = "Arabic + English"
    case urduFocus = "Arabic + Urdu"

    var id: String { rawValue }
}

enum TextAlignMode: String, CaseIterable, Identifiable {
    case center = "Center"
    case natural = "Natural (RTL)"
    case leading = "Leading"

    var id: String { rawValue }

    var swiftUI: TextAlignment {
        switch self {
        case .center: return .center
        case .natural: return .trailing
        case .leading: return .leading
        }
    }

    var frame: Alignment {
        switch self {
        case .center: return .center
        case .natural: return .trailing
        case .leading: return .leading
        }
    }
}

enum ScriptFont: String, CaseIterable, Identifiable {
    // System
    case system = "System"
    case geeza = "Geeza Pro"
    case alNile = "Al Nile"
    case damascus = "Damascus"
    case farah = "Farah"
    case diwanKufi = "Diwan Kufi"
    case rounded = "Rounded"
    case serif = "Serif"
    case mono = "Monospaced"

    // Bundled — Indo-Pak / Quran / Arabic
    case indoPak = "Indo-Pak Nastaleeq"
    case uthmani = "Uthmanic Hafs"
    case meQuran = "me Quran"
    case mehrNastaliq = "Mehr Nastaliq"
    case notoNaskh = "Noto Naskh Arabic"
    case notoNastaliq = "Noto Nastaliq Urdu"
    case amiri = "Amiri"
    case scheherazade = "Scheherazade New"
    case lateef = "Lateef"
    case harmattan = "Harmattan"
    case ibmPlex = "IBM Plex Sans Arabic"
    case reemKufi = "Reem Kufi"
    case gulzar = "Gulzar"

    var id: String { rawValue }

    /// PostScript name for bundled fonts; nil → system design mapping.
    var postScriptName: String? {
        switch self {
        case .indoPak: return "AlQuran-IndoPak-by-QuranWBW"
        case .uthmani: return "KFGQPCHAFSUthmanicScript-Regula"
        case .meQuran: return "me_quran2"
        case .mehrNastaliq: return "MehrNastaliqWeb"
        case .notoNaskh: return "NotoNaskhArabic-Regular"
        case .notoNastaliq: return "NotoNastaliqUrdu-Regular"
        case .amiri: return "Amiri-Regular"
        case .scheherazade: return "ScheherazadeNew-Regular"
        case .lateef: return "Lateef-Regular"
        case .harmattan: return "Harmattan-Regular"
        case .ibmPlex: return "IBMPlexSansArabic-Regular"
        case .reemKufi: return "ReemKufi"
        case .gulzar: return "Gulzar-Regular"
        case .geeza: return "GeezaPro"
        case .alNile: return "AlNile"
        case .damascus: return "Damascus"
        case .farah: return "Farah"
        case .diwanKufi: return "DiwanKufi"
        default: return nil
        }
    }

    static var arabicChoices: [ScriptFont] {
        [
            .indoPak, .uthmani, .meQuran, .amiri, .notoNaskh, .scheherazade,
            .lateef, .harmattan, .ibmPlex, .reemKufi, .mehrNastaliq, .notoNastaliq,
            .geeza, .alNile, .damascus, .farah, .diwanKufi, .system
        ]
    }

    static var urduChoices: [ScriptFont] {
        [
            .gulzar, .indoPak, .mehrNastaliq, .notoNastaliq, .notoNaskh, .amiri,
            .scheherazade, .lateef, .geeza, .alNile, .system, .serif
        ]
    }

    static var englishChoices: [ScriptFont] { [.system, .rounded, .serif, .mono, .ibmPlex] }

    func font(size: CGFloat) -> Font {
        if let ps = postScriptName {
            return .custom(ps, size: size)
        }
        switch self {
        case .system: return .system(size: size)
        case .rounded: return .system(size: size, design: .rounded)
        case .serif: return .system(size: size, design: .serif)
        case .mono: return .system(size: size, design: .monospaced)
        default: return .system(size: size)
        }
    }
}

@MainActor
final class ReadingSettings: ObservableObject {
    @Published var showArabic: Bool { didSet { save() } }
    @Published var showEnglish: Bool { didSet { save() } }
    @Published var showUrdu: Bool { didSet { save() } }

    @Published var arabicFont: ScriptFont { didSet { save() } }
    @Published var englishFont: ScriptFont { didSet { save() } }
    @Published var urduFont: ScriptFont { didSet { save() } }

    @Published var arabicSize: Double { didSet { save() } }
    @Published var englishSize: Double { didSet { save() } }
    @Published var urduSize: Double { didSet { save() } }
    /// Extra spacing between Arabic lines (0 = tight).
    @Published var arabicLineSpacing: Double { didSet { save() } }
    /// Extra spacing between Urdu lines (Nastaliq needs more air).
    @Published var urduLineSpacing: Double { didSet { save() } }

    @Published var arabicColor: Color { didSet { save() } }
    @Published var englishColor: Color { didSet { save() } }
    @Published var urduColor: Color { didSet { save() } }

    /// How reminder/reader text is aligned.
    @Published var textAlign: TextAlignMode { didSet { save() } }
    @Published var showLangLabels: Bool { didSet { save() } }
    @Published var readingLanguage: AppReadingLanguage { didSet {
        applyReadingLanguage()
        save()
    }}

    @Published var englishTranslationID: Int { didSet {
        UserDefaults.standard.set(englishTranslationID, forKey: "beummati.enTranslationID")
        save()
    }}
    @Published var urduTranslationID: Int { didSet {
        UserDefaults.standard.set(urduTranslationID, forKey: "beummati.urTranslationID")
        save()
    }}

    /// Languages included when sharing (pick any combination).
    @Published var shareArabic: Bool { didSet { save() } }
    @Published var shareEnglish: Bool { didSet { save() } }
    @Published var shareUrdu: Bool { didSet { save() } }

    private let key = "beummati.readingSettings.v1"

    init() {
        let d = UserDefaults.standard
        showArabic = d.object(forKey: key + ".showAr") as? Bool ?? true
        showEnglish = d.object(forKey: key + ".showEn") as? Bool ?? true
        showUrdu = d.object(forKey: key + ".showUr") as? Bool ?? true
        arabicFont = ScriptFont(rawValue: d.string(forKey: key + ".arFont") ?? "") ?? .indoPak
        englishFont = ScriptFont(rawValue: d.string(forKey: key + ".enFont") ?? "") ?? .system
        urduFont = ScriptFont(rawValue: d.string(forKey: key + ".urFont") ?? "") ?? .mehrNastaliq
        arabicSize = d.object(forKey: key + ".arSize") as? Double ?? 26
        englishSize = d.object(forKey: key + ".enSize") as? Double ?? 18
        urduSize = d.object(forKey: key + ".urSize") as? Double ?? 20
        arabicLineSpacing = d.object(forKey: key + ".arLine") as? Double ?? 0
        urduLineSpacing = d.object(forKey: key + ".urLine") as? Double ?? 2
        let ink = Color(red: 0.16, green: 0.14, blue: 0.12)
        arabicColor = Self.loadColor(d, key: key + ".arColor") ?? ink
        englishColor = Self.loadColor(d, key: key + ".enColor") ?? ink
        urduColor = Self.loadColor(d, key: key + ".urColor") ?? ink
        textAlign = TextAlignMode(rawValue: d.string(forKey: key + ".align") ?? "") ?? .center
        showLangLabels = d.object(forKey: key + ".labels") as? Bool ?? true
        readingLanguage = AppReadingLanguage(rawValue: d.string(forKey: key + ".appLang") ?? "") ?? .allThree
        shareArabic = d.object(forKey: key + ".shareAr") as? Bool ?? true
        shareEnglish = d.object(forKey: key + ".shareEn") as? Bool ?? true
        shareUrdu = d.object(forKey: key + ".shareUr") as? Bool ?? true
        let en = d.integer(forKey: "beummati.enTranslationID")
        englishTranslationID = en == 0 ? 85 : en
        let ur = d.integer(forKey: "beummati.urTranslationID")
        urduTranslationID = ur == 0 ? 54 : ur
        d.set(englishTranslationID, forKey: "beummati.enTranslationID")
        d.set(urduTranslationID, forKey: "beummati.urTranslationID")
    }

    /// Prefer a clean Nastaliq stack for Urdu when available.
    func ensureManuscriptDefaults() {
        let flag = "beummati.manuscriptTheme.v1"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        arabicFont = .amiri
        urduFont = .notoNastaliq
        let ink = Color(red: 0.16, green: 0.14, blue: 0.12)
        arabicColor = ink
        englishColor = ink
        urduColor = ink
        textAlign = .natural
        showLangLabels = false
        urduLineSpacing = 2
        arabicLineSpacing = 0
        englishSize = 18
        urduSize = 20
        UserDefaults.standard.set(true, forKey: flag)
        save()
    }

    func applyReadingLanguage(force: Bool = true) {
        switch readingLanguage {
        case .allThree:
            showArabic = true
            showEnglish = true
            showUrdu = true
        case .englishFocus:
            showArabic = true
            showEnglish = true
            showUrdu = false
        case .urduFocus:
            showArabic = true
            showEnglish = false
            showUrdu = true
        }
    }

    func reset() {
        showArabic = true
        showEnglish = true
        showUrdu = true
        readingLanguage = .allThree
        arabicFont = .indoPak
        englishFont = .system
        urduFont = .notoNastaliq
        arabicSize = 26
        englishSize = 18
        urduSize = 20
        arabicLineSpacing = 0
        urduLineSpacing = 2
        let ink = Color(red: 0.16, green: 0.14, blue: 0.12)
        arabicColor = ink
        englishColor = ink
        urduColor = ink
        textAlign = .center
        showLangLabels = true
        englishTranslationID = 85
        urduTranslationID = 54
        shareArabic = true
        shareEnglish = true
        shareUrdu = true
        save()
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(showArabic, forKey: key + ".showAr")
        d.set(showEnglish, forKey: key + ".showEn")
        d.set(showUrdu, forKey: key + ".showUr")
        d.set(arabicFont.rawValue, forKey: key + ".arFont")
        d.set(englishFont.rawValue, forKey: key + ".enFont")
        d.set(urduFont.rawValue, forKey: key + ".urFont")
        d.set(arabicSize, forKey: key + ".arSize")
        d.set(englishSize, forKey: key + ".enSize")
        d.set(urduSize, forKey: key + ".urSize")
        d.set(arabicLineSpacing, forKey: key + ".arLine")
        d.set(urduLineSpacing, forKey: key + ".urLine")
        d.set(textAlign.rawValue, forKey: key + ".align")
        d.set(showLangLabels, forKey: key + ".labels")
        d.set(readingLanguage.rawValue, forKey: key + ".appLang")
        d.set(englishTranslationID, forKey: "beummati.enTranslationID")
        d.set(urduTranslationID, forKey: "beummati.urTranslationID")
        d.set(shareArabic, forKey: key + ".shareAr")
        d.set(shareEnglish, forKey: key + ".shareEn")
        d.set(shareUrdu, forKey: key + ".shareUr")
        Self.storeColor(arabicColor, d, key: key + ".arColor")
        Self.storeColor(englishColor, d, key: key + ".enColor")
        Self.storeColor(urduColor, d, key: key + ".urColor")
    }

    private static func storeColor(_ color: Color, _ d: UserDefaults, key: String) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        d.set([Double(r), Double(g), Double(b), Double(a)], forKey: key)
    }

    private static func loadColor(_ d: UserDefaults, key: String) -> Color? {
        guard let arr = d.array(forKey: key) as? [Double], arr.count == 4 else { return nil }
        return Color(.sRGB, red: arr[0], green: arr[1], blue: arr[2], opacity: arr[3])
    }
}
