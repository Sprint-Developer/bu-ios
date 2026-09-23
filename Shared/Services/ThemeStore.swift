import SwiftUI
import Combine

enum AppThemeKind: String, CaseIterable, Identifiable {
    case manuscript
    case midnight
    case emerald
    case ocean
    case ummati
    case softDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manuscript: return "Manuscript"
        case .midnight: return "Midnight"
        case .emerald: return "Emerald"
        case .ocean: return "Ocean"
        case .ummati: return "Ummati"
        case .softDay: return "Soft Day"
        }
    }

    var subtitle: String {
        switch self {
        case .manuscript: return "Parchment · teal · brass"
        case .midnight: return "Dark night · gold accents"
        case .emerald: return "Deep green · cream"
        case .ocean: return "Cool blue · soft mist"
        case .ummati: return "Red · white · charcoal (brand)"
        case .softDay: return "Light airy · sage"
        }
    }

    var isDark: Bool {
        switch self {
        case .midnight, .ummati: return true
        default: return false
        }
    }

    var palette: ThemePalette {
        switch self {
        case .manuscript:
            return ThemePalette(
                parchment: Color(red: 0.965, green: 0.945, blue: 0.902),
                parchmentDeep: Color(red: 0.94, green: 0.91, blue: 0.85),
                teal: Color(red: 0.12, green: 0.28, blue: 0.29),
                tealSoft: Color(red: 0.12, green: 0.28, blue: 0.29).opacity(0.12),
                tealMuted: Color(red: 0.22, green: 0.42, blue: 0.43),
                brass: Color(red: 0.72, green: 0.58, blue: 0.32),
                brassSoft: Color(red: 0.72, green: 0.58, blue: 0.32).opacity(0.18),
                card: Color.white.opacity(0.72),
                ink: Color(red: 0.16, green: 0.14, blue: 0.12),
                inkSecondary: Color(red: 0.35, green: 0.32, blue: 0.28)
            )
        case .midnight:
            return ThemePalette(
                parchment: Color(red: 0.07, green: 0.08, blue: 0.10),
                parchmentDeep: Color(red: 0.11, green: 0.12, blue: 0.15),
                teal: Color(red: 0.35, green: 0.62, blue: 0.62),
                tealSoft: Color(red: 0.35, green: 0.62, blue: 0.62).opacity(0.18),
                tealMuted: Color(red: 0.28, green: 0.48, blue: 0.50),
                brass: Color(red: 0.85, green: 0.70, blue: 0.38),
                brassSoft: Color(red: 0.85, green: 0.70, blue: 0.38).opacity(0.20),
                card: Color(red: 0.14, green: 0.15, blue: 0.18),
                ink: Color(red: 0.94, green: 0.93, blue: 0.90),
                inkSecondary: Color(red: 0.65, green: 0.64, blue: 0.60)
            )
        case .emerald:
            return ThemePalette(
                parchment: Color(red: 0.95, green: 0.96, blue: 0.93),
                parchmentDeep: Color(red: 0.90, green: 0.93, blue: 0.88),
                teal: Color(red: 0.10, green: 0.35, blue: 0.28),
                tealSoft: Color(red: 0.10, green: 0.35, blue: 0.28).opacity(0.12),
                tealMuted: Color(red: 0.20, green: 0.48, blue: 0.38),
                brass: Color(red: 0.62, green: 0.48, blue: 0.22),
                brassSoft: Color(red: 0.62, green: 0.48, blue: 0.22).opacity(0.18),
                card: Color.white.opacity(0.78),
                ink: Color(red: 0.12, green: 0.16, blue: 0.14),
                inkSecondary: Color(red: 0.32, green: 0.38, blue: 0.34)
            )
        case .ocean:
            return ThemePalette(
                parchment: Color(red: 0.93, green: 0.95, blue: 0.97),
                parchmentDeep: Color(red: 0.88, green: 0.91, blue: 0.94),
                teal: Color(red: 0.12, green: 0.32, blue: 0.48),
                tealSoft: Color(red: 0.12, green: 0.32, blue: 0.48).opacity(0.12),
                tealMuted: Color(red: 0.25, green: 0.45, blue: 0.58),
                brass: Color(red: 0.55, green: 0.45, blue: 0.28),
                brassSoft: Color(red: 0.55, green: 0.45, blue: 0.28).opacity(0.18),
                card: Color.white.opacity(0.80),
                ink: Color(red: 0.12, green: 0.16, blue: 0.22),
                inkSecondary: Color(red: 0.35, green: 0.40, blue: 0.46)
            )
        case .ummati:
            return ThemePalette(
                parchment: Color(red: 0.06, green: 0.06, blue: 0.07),
                parchmentDeep: Color(red: 0.10, green: 0.10, blue: 0.11),
                teal: Color(red: 0.72, green: 0.12, blue: 0.14),
                tealSoft: Color(red: 0.72, green: 0.12, blue: 0.14).opacity(0.20),
                tealMuted: Color(red: 0.55, green: 0.18, blue: 0.20),
                brass: Color(red: 0.92, green: 0.92, blue: 0.92),
                brassSoft: Color.white.opacity(0.12),
                card: Color(red: 0.13, green: 0.13, blue: 0.14),
                ink: Color(red: 0.96, green: 0.96, blue: 0.96),
                inkSecondary: Color(red: 0.62, green: 0.60, blue: 0.60)
            )
        case .softDay:
            return ThemePalette(
                parchment: Color(red: 0.98, green: 0.98, blue: 0.97),
                parchmentDeep: Color(red: 0.94, green: 0.95, blue: 0.93),
                teal: Color(red: 0.28, green: 0.42, blue: 0.36),
                tealSoft: Color(red: 0.28, green: 0.42, blue: 0.36).opacity(0.12),
                tealMuted: Color(red: 0.38, green: 0.52, blue: 0.46),
                brass: Color(red: 0.58, green: 0.46, blue: 0.30),
                brassSoft: Color(red: 0.58, green: 0.46, blue: 0.30).opacity(0.16),
                card: Color.white,
                ink: Color(red: 0.18, green: 0.18, blue: 0.18),
                inkSecondary: Color(red: 0.45, green: 0.45, blue: 0.45)
            )
        }
    }
}

struct ThemePalette {
    let parchment: Color
    let parchmentDeep: Color
    let teal: Color
    let tealSoft: Color
    let tealMuted: Color
    let brass: Color
    let brassSoft: Color
    let card: Color
    let ink: Color
    let inkSecondary: Color
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published var kind: AppThemeKind {
        didSet { UserDefaults.standard.set(kind.rawValue, forKey: key + ".kind") }
    }

    @Published var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: key + ".appearance") }
    }

    private let key = "beummati.appTheme.v1"

    var palette: ThemePalette { kind.palette }

    init() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: key + ".kind"), let k = AppThemeKind(rawValue: raw) {
            kind = k
        } else {
            kind = .manuscript
        }
        if let raw = d.string(forKey: key + ".appearance"), let a = AppAppearance(rawValue: raw) {
            appearance = a
        } else {
            appearance = .system
        }
    }
}
