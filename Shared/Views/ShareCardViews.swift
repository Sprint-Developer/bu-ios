import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Brand tokens (Be Ummati share graphics)
// Canvas sized for IG Stories (9:16). ImageRenderer scale 3 ≈ 1620×2880.

private enum BeUmmatiShare {
    static let brandRed = Color(red: 0.90, green: 0.0, blue: 0.05)
    static let sloganTeal = Color(red: 0.32, green: 0.82, blue: 0.84)
    static let quranTop = Color(red: 0.03, green: 0.16, blue: 0.24)
    static let quranMid = Color(red: 0.02, green: 0.08, blue: 0.14)
    static let hadithTeal = Color(red: 0.04, green: 0.30, blue: 0.32)
    static let reminderBg = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let verticalSlogan = "FOLLOW MUHAMMAD PBUH IF YOU LOVE ALLAH"

    /// Story canvas
    static let cardWidth: CGFloat = 540
    static let portraitHeight: CGFloat = 960
    /// Reminder template is closer to square / 4:5
    static let reminderHeight: CGFloat = 640
    static let sloganWidth: CGFloat = 36
    static let contentInset: CGFloat = 36
}

enum ShareCardStyle: String, CaseIterable, Identifiable {
    case dailyQuran
    case hadithTeal
    case reminderBold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dailyQuran: return "Daily Quran"
        case .hadithTeal: return "Hadith"
        case .reminderBold: return "Reminder"
        }
    }

    static func preferred(for kind: String?) -> ShareCardStyle {
        let k = (kind ?? "").lowercased()
        if k.contains("qur") || k.contains("ayah") || k.contains("verse") { return .dailyQuran }
        if k.contains("hadith") || k.contains("bukhari") || k.contains("muslim") { return .hadithTeal }
        return .reminderBold
    }
}

/// Background color themes shared by all share-card designs.
enum ShareCardTheme: String, CaseIterable, Identifiable {
    case classic
    case ocean
    case emerald
    case midnight
    case maghrib
    case ummati
    case slate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: return "Classic"
        case .ocean: return "Ocean"
        case .emerald: return "Emerald"
        case .midnight: return "Midnight"
        case .maghrib: return "Maghrib"
        case .ummati: return "Ummati"
        case .slate: return "Slate"
        }
    }

    /// Swatch colors for the theme picker chips.
    var swatch: [Color] {
        switch self {
        case .classic:
            return [
                Color(red: 0.03, green: 0.20, blue: 0.30),
                Color(red: 0.04, green: 0.30, blue: 0.32),
                .black
            ]
        case .ocean:
            return [
                Color(red: 0.05, green: 0.28, blue: 0.48),
                Color(red: 0.02, green: 0.14, blue: 0.28),
                Color(red: 0.01, green: 0.05, blue: 0.12)
            ]
        case .emerald:
            return [
                Color(red: 0.05, green: 0.32, blue: 0.26),
                Color(red: 0.03, green: 0.18, blue: 0.16),
                Color(red: 0.02, green: 0.08, blue: 0.07)
            ]
        case .midnight:
            return [
                Color(red: 0.08, green: 0.09, blue: 0.16),
                Color(red: 0.04, green: 0.04, blue: 0.08),
                .black
            ]
        case .maghrib:
            return [
                Color(red: 0.42, green: 0.14, blue: 0.18),
                Color(red: 0.22, green: 0.06, blue: 0.12),
                Color(red: 0.08, green: 0.03, blue: 0.05)
            ]
        case .ummati:
            return [
                Color(red: 0.55, green: 0.05, blue: 0.10),
                Color(red: 0.28, green: 0.02, blue: 0.06),
                Color(red: 0.08, green: 0.02, blue: 0.03)
            ]
        case .slate:
            return [
                Color(red: 0.22, green: 0.26, blue: 0.32),
                Color(red: 0.12, green: 0.14, blue: 0.18),
                Color(red: 0.05, green: 0.06, blue: 0.08)
            ]
        }
    }

    /// Daily Quran top panel gradient (top → bottom).
    var quranTopGradient: [Color] {
        switch self {
        case .classic:
            return [
                Color(red: 0.03, green: 0.20, blue: 0.30),
                Color(red: 0.02, green: 0.09, blue: 0.16),
                .black
            ]
        case .ocean:
            return [
                Color(red: 0.06, green: 0.32, blue: 0.52),
                Color(red: 0.03, green: 0.16, blue: 0.32),
                Color(red: 0.01, green: 0.05, blue: 0.14)
            ]
        case .emerald:
            return [
                Color(red: 0.06, green: 0.36, blue: 0.30),
                Color(red: 0.03, green: 0.18, blue: 0.17),
                Color(red: 0.02, green: 0.07, blue: 0.07)
            ]
        case .midnight:
            return [
                Color(red: 0.10, green: 0.11, blue: 0.20),
                Color(red: 0.05, green: 0.05, blue: 0.10),
                .black
            ]
        case .maghrib:
            return [
                Color(red: 0.48, green: 0.16, blue: 0.20),
                Color(red: 0.24, green: 0.07, blue: 0.12),
                Color(red: 0.06, green: 0.02, blue: 0.04)
            ]
        case .ummati:
            return [
                Color(red: 0.58, green: 0.06, blue: 0.10),
                Color(red: 0.28, green: 0.02, blue: 0.05),
                Color(red: 0.06, green: 0.01, blue: 0.02)
            ]
        case .slate:
            return [
                Color(red: 0.26, green: 0.30, blue: 0.36),
                Color(red: 0.12, green: 0.14, blue: 0.18),
                Color(red: 0.04, green: 0.05, blue: 0.06)
            ]
        }
    }

    /// Hadith top panel fill.
    var hadithFill: Color {
        switch self {
        case .classic: return BeUmmatiShare.hadithTeal
        case .ocean: return Color(red: 0.04, green: 0.28, blue: 0.42)
        case .emerald: return Color(red: 0.05, green: 0.34, blue: 0.28)
        case .midnight: return Color(red: 0.10, green: 0.12, blue: 0.22)
        case .maghrib: return Color(red: 0.40, green: 0.14, blue: 0.20)
        case .ummati: return Color(red: 0.48, green: 0.05, blue: 0.10)
        case .slate: return Color(red: 0.20, green: 0.24, blue: 0.30)
        }
    }

    /// Bottom panel / Reminder solid background.
    var base: Color {
        switch self {
        case .classic: return .black
        case .ocean: return Color(red: 0.01, green: 0.04, blue: 0.10)
        case .emerald: return Color(red: 0.02, green: 0.06, blue: 0.06)
        case .midnight: return .black
        case .maghrib: return Color(red: 0.05, green: 0.02, blue: 0.03)
        case .ummati: return Color(red: 0.05, green: 0.01, blue: 0.02)
        case .slate: return Color(red: 0.04, green: 0.05, blue: 0.06)
        }
    }

    /// Vertical slogan accent.
    var slogan: Color {
        switch self {
        case .classic: return BeUmmatiShare.sloganTeal
        case .ocean: return Color(red: 0.45, green: 0.85, blue: 0.95)
        case .emerald: return Color(red: 0.45, green: 0.92, blue: 0.78)
        case .midnight: return Color(red: 0.70, green: 0.75, blue: 0.95)
        case .maghrib: return Color(red: 1.0, green: 0.72, blue: 0.55)
        case .ummati: return Color(red: 1.0, green: 0.55, blue: 0.55)
        case .slate: return Color(red: 0.75, green: 0.82, blue: 0.90)
        }
    }

    /// Daily Quran title gradient stops.
    var titleGradientStops: [Gradient.Stop] {
        switch self {
        case .classic:
            return [
                .init(color: Color(red: 0.55, green: 0.98, blue: 0.92), location: 0.0),
                .init(color: Color(red: 0.35, green: 0.90, blue: 0.88), location: 0.22),
                .init(color: Color(red: 0.22, green: 0.62, blue: 0.78), location: 0.48),
                .init(color: Color(red: 0.28, green: 0.32, blue: 0.72), location: 0.72),
                .init(color: Color(red: 0.18, green: 0.12, blue: 0.42), location: 1.0)
            ]
        case .ocean:
            return [
                .init(color: Color(red: 0.70, green: 0.95, blue: 1.0), location: 0.0),
                .init(color: Color(red: 0.35, green: 0.75, blue: 0.95), location: 0.4),
                .init(color: Color(red: 0.15, green: 0.35, blue: 0.75), location: 1.0)
            ]
        case .emerald:
            return [
                .init(color: Color(red: 0.65, green: 1.0, blue: 0.85), location: 0.0),
                .init(color: Color(red: 0.30, green: 0.85, blue: 0.65), location: 0.4),
                .init(color: Color(red: 0.10, green: 0.45, blue: 0.40), location: 1.0)
            ]
        case .midnight:
            return [
                .init(color: Color(red: 0.85, green: 0.88, blue: 1.0), location: 0.0),
                .init(color: Color(red: 0.55, green: 0.60, blue: 0.90), location: 0.45),
                .init(color: Color(red: 0.30, green: 0.28, blue: 0.55), location: 1.0)
            ]
        case .maghrib:
            return [
                .init(color: Color(red: 1.0, green: 0.85, blue: 0.55), location: 0.0),
                .init(color: Color(red: 1.0, green: 0.55, blue: 0.40), location: 0.4),
                .init(color: Color(red: 0.70, green: 0.20, blue: 0.30), location: 1.0)
            ]
        case .ummati:
            return [
                .init(color: Color(red: 1.0, green: 0.75, blue: 0.75), location: 0.0),
                .init(color: Color(red: 1.0, green: 0.35, blue: 0.35), location: 0.4),
                .init(color: Color(red: 0.55, green: 0.05, blue: 0.10), location: 1.0)
            ]
        case .slate:
            return [
                .init(color: Color(red: 0.90, green: 0.93, blue: 0.98), location: 0.0),
                .init(color: Color(red: 0.65, green: 0.72, blue: 0.82), location: 0.45),
                .init(color: Color(red: 0.35, green: 0.40, blue: 0.50), location: 1.0)
            ]
        }
    }
}

// MARK: - Shared brand chrome

private struct BeUmmatiBadge: View {
    /// When true, red bar sits near the left edge (Daily Quran template).
    var flushLeft: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Be Ummati")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(BeUmmatiShare.brandRed)
            // Tag sits slightly in from the red bar’s left edge
            Text("Soldier of Allah")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.leading, flushLeft ? 10 : 2)
        }
        .padding(.leading, flushLeft ? 0 : 0)
    }
}

/// Vertical slogan drawn ON TOP of the card (no side rail / no bg strip).
private struct VerticalSloganOverlay: View {
    var color: Color = BeUmmatiShare.sloganTeal

    var body: some View {
        Text(BeUmmatiShare.verticalSlogan)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(4)
            .foregroundStyle(color)
            .fixedSize()
            .rotationEffect(.degrees(-90))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 6)
            .allowsHitTesting(false)
    }
}

/// Legacy rail (Hadith still uses a teal strip).
private struct VerticalSloganBar: View {
    var color: Color = BeUmmatiShare.sloganTeal
    var barBackground: Color = .clear

    var body: some View {
        ZStack {
            barBackground
            Text(BeUmmatiShare.verticalSlogan)
                .font(.system(size: 11, weight: .bold))
                .tracking(3.5)
                .foregroundStyle(color)
                .fixedSize()
                .rotationEffect(.degrees(-90))
        }
        .frame(width: BeUmmatiShare.sloganWidth)
        .frame(maxHeight: .infinity)
        .clipped()
    }
}

private struct HadithMasthead: View {
    var kind: String?

    var body: some View {
        let label = Self.parts(for: kind)
        VStack(alignment: .leading, spacing: 2) {
            Text(label.top)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
            Text(label.mid)
                .font(.system(size: 22, weight: .heavy))
                .tracking(0.5)
            Text(label.bot)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .stroke(.white.opacity(0.9), lineWidth: 1.2)
        )
    }

    private static func parts(for kind: String?) -> (top: String, mid: String, bot: String) {
        let k = (kind ?? "").uppercased()
        if k.contains("MUSLIM") { return ("SAHIH", "MUSLIM", "HADITH") }
        if k.contains("BUKHARI") || k.contains("HADITH") || k.isEmpty {
            return ("SAHIH AL", "BUKHARI", "HADITH")
        }
        return ("", k, "HADITH")
    }
}

/// Feather + ink decorative art for Hadith masthead (real asset; black bg screened out).
private struct QuillDecoration: View {
    var body: some View {
        Image("ShareFeather")
            .resizable()
            .scaledToFit()
            .blendMode(.screen)
            .opacity(0.72)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Card styles

struct ShareCardView: View {
    let style: ShareCardStyle
    var theme: ShareCardTheme = .classic
    let title: String?
    let kind: String?
    let ref: String
    let arabic: String
    let english: String
    let urdu: String
    let showArabic: Bool
    let showEnglish: Bool
    let showUrdu: Bool
    var showBrand: Bool = true
    var showSlogan: Bool = true
    var showReference: Bool = true

    var body: some View {
        switch style {
        case .dailyQuran: dailyQuranCard
        case .hadithTeal: hadithCard
        case .reminderBold: reminderCard
        }
    }

    // MARK: Daily Quran — verified against Be Ummati template PNG

    private var dailyQuranCard: some View {
        let W = BeUmmatiShare.cardWidth
        let H = BeUmmatiShare.portraitHeight
        let topH = H * 0.50
        let botH = H - topH

        return ZStack {
            VStack(spacing: 0) {
                // TOP — theme gradient
                ZStack {
                    LinearGradient(
                        colors: theme.quranTopGradient,
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        // Instrument Serif — theme title gradient
                        Text("Daily Quran")
                            .font(dailyQuranTitleFont(size: 40))
                            .tracking(0.6)
                            .foregroundStyle(
                                LinearGradient(
                                    stops: theme.titleGradientStops,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .padding(.top, 22)
                            .padding(.leading, 16)

                        Spacer(minLength: 0)

                        VStack(spacing: 14) {
                            if showArabic, !arabic.isEmpty {
                                Text(arabic)
                                    .font(quranArabicFont(size: uthmaniSize(for: arabic)))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(8)
                                    .minimumScaleFactor(0.65)
                                    .frame(maxWidth: .infinity)
                            }
                            if showUrdu, !urdu.isEmpty {
                                Text(urdu)
                                    .font(shareUrduFont(size: 20))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(6)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.leading, 30)
                        .padding(.trailing, 42)
                        .padding(.bottom, 28)

                        Spacer(minLength: 0)
                    }
                }
                .frame(height: topH)

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)

                // BOTTOM — theme base
                ZStack(alignment: .bottomLeading) {
                    theme.base

                    VStack(spacing: 16) {
                        Spacer(minLength: 28)
                        if showEnglish, !english.isEmpty {
                            Text(english)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .minimumScaleFactor(0.8)
                                .padding(.leading, 36)
                                .padding(.trailing, 44)
                        }
                        if showReference, !ref.isEmpty {
                            Text(displayRef.uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        Spacer(minLength: 64)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showBrand {
                        // Truly flush — zero leading inset
                        BeUmmatiBadge(flushLeft: true)
                            .padding(.bottom, 20)
                    }
                }
                .frame(height: botH)
            }

            // Overlay on art — GeometryReader position, no rail bg
            if showSlogan {
                GeometryReader { geo in
                    Text(BeUmmatiShare.verticalSlogan)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3.5)
                        .foregroundStyle(theme.slogan)
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .position(x: geo.size.width - 12, y: geo.size.height * 0.52)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: W, height: H)
        .clipped()
    }

    private func dailyQuranTitleFont(size: CGFloat) -> Font {
        // Instrument Serif — elegant tall display for “Daily Quran”
        if UIFont(name: "InstrumentSerif-Regular", size: size) != nil {
            return .custom("InstrumentSerif-Regular", size: size)
        }
        for name in ["AvenirNext-UltraLight", "HelveticaNeue-UltraLight"] {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size, weight: .ultraLight, design: .serif)
    }

    /// Readable Urdu — Gulzar (Nastaliq) preferred, then Naskh / system.
    private func shareUrduFont(size: CGFloat) -> Font {
        for name in ["Gulzar-Regular", "NotoNaskhArabic-Regular", "GeezaPro", "Amiri-Regular"] {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size, weight: .regular)
    }

    private func quranArabicFont(size: CGFloat) -> Font {
        for name in ["KFGQPCHAFSUthmanicScript-Regula", "me_quran2", "Amiri-Regular"] {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size)
    }

    private func uthmaniSize(for text: String) -> CGFloat {
        let n = text.count
        if n < 50 { return 34 }
        if n < 100 { return 28 }
        if n < 180 { return 24 }
        return 20
    }

    // MARK: Hadith — same rules as Daily Quran (overlay slogan, flush badge)

    private var hadithCard: some View {
        let W = BeUmmatiShare.cardWidth
        let H = BeUmmatiShare.portraitHeight
        let topH = H * 0.40
        let botH = H - topH

        return ZStack {
            VStack(spacing: 0) {
                ZStack {
                    theme.hadithFill

                    // Feather art — trailing, soft, behind masthead type
                    QuillDecoration()
                        .frame(width: W * 0.78)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, -28)
                        .padding(.top, 8)
                        .offset(y: 12)

                    VStack(alignment: .leading, spacing: 0) {
                        HadithMasthead(kind: kind)
                            .padding(.top, 28)
                            .padding(.leading, 16)

                        Spacer(minLength: 8)

                        VStack(spacing: 10) {
                            if let headerAr = hadithHeaderArabic {
                                Text(headerAr)
                                    .font(quranArabicFont(size: 32))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(6)
                                    .minimumScaleFactor(0.65)
                            } else if let title, !title.isEmpty {
                                Text(title)
                                    .font(.system(size: 24, weight: .semibold, design: .serif))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.7)
                            }
                            if let sub = hadithEnglishHeader {
                                Text(sub)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.leading, 28)
                        .padding(.trailing, 42)
                        .padding(.bottom, 22)

                        Spacer(minLength: 0)
                    }
                }
                .frame(height: topH)

                ZStack(alignment: .bottomLeading) {
                    theme.base
                    VStack(spacing: 16) {
                        Spacer(minLength: 28)
                        if let body = hadithBodyText {
                            Text(body)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .minimumScaleFactor(0.72)
                                .padding(.leading, 32)
                                .padding(.trailing, 44)
                        } else if showUrdu, !urdu.isEmpty {
                            Text(urdu)
                                .font(shareUrduFont(size: 20))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.leading, 32)
                                .padding(.trailing, 44)
                        }
                        if showReference, !ref.isEmpty {
                            Text(hadithRefLabel)
                                .font(.system(size: 12, weight: .bold))
                                .tracking(2.2)
                                .foregroundStyle(.white)
                        }
                        Spacer(minLength: 64)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if showBrand {
                        BeUmmatiBadge(flushLeft: true)
                            .padding(.bottom, 20)
                    }
                }
                .frame(height: botH)
            }

            if showSlogan {
                GeometryReader { geo in
                    Text(BeUmmatiShare.verticalSlogan)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3.5)
                        .foregroundStyle(theme.slogan.opacity(0.95))
                        .fixedSize()
                        .rotationEffect(.degrees(-90))
                        .position(x: geo.size.width - 12, y: geo.size.height * 0.52)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: W, height: H)
        .clipped()
    }

    // MARK: Reminder — thin tall type, red accents, flush Be Ummati badge

    private var reminderCard: some View {
        let W = BeUmmatiShare.cardWidth
        let H = BeUmmatiShare.reminderHeight

        return ZStack(alignment: .bottomLeading) {
            theme.base

            VStack(alignment: .leading, spacing: 0) {
                reminderHeaderBlock
                    .padding(.top, 32)
                    .padding(.leading, 22)
                    .padding(.trailing, 24)

                ZStack(alignment: .topTrailing) {
                    Color.clear.frame(height: reminderAccentLine == nil ? 8 : 44)
                    if let accent = reminderAccentLine {
                        Text(accent)
                            .font(.system(size: 22, weight: .regular, design: .serif).italic())
                            .foregroundStyle(BeUmmatiShare.brandRed)
                            .rotationEffect(.degrees(-12), anchor: .center)
                            .padding(.trailing, 20)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(reminderBullets, id: \.self) { line in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrowtriangle.right.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(BeUmmatiShare.brandRed)
                                .padding(.top, 6)
                            Text(line)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 22)
                .padding(.trailing, 28)
                .padding(.bottom, 72)
            }

            if showBrand {
                BeUmmatiBadge(flushLeft: true)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: W, height: H)
        .clipped()
    }

    @ViewBuilder
    private var reminderHeaderBlock: some View {
        if usesClassicCallUponLayout {
            VStack(alignment: .leading, spacing: 2) {
                // AND YOUR LORD SAYS, ❤️ — LORD tall + thin
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("AND YOUR")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(BeUmmatiShare.brandRed)
                    Text("LORD")
                        .font(.system(size: 48, weight: .ultraLight))
                        .tracking(1.5)
                        .foregroundStyle(BeUmmatiShare.brandRed)
                    Text("SAYS,")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("❤️")
                        .font(.system(size: 13))
                        .baselineOffset(2)
                }
                Text("CALL UPON ME")
                    .font(.system(size: 42, weight: .ultraLight))
                    .tracking(1.8)
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                if showReference, !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .tracking(2.4)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 8)
                }
            }
        } else if let hook = reminderHook {
            VStack(alignment: .leading, spacing: 6) {
                Text(hook.eyebrow)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(BeUmmatiShare.brandRed)
                Text(hook.headline)
                    .font(.system(size: 36, weight: .ultraLight))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.65)
                    .lineLimit(3)
                if showReference, !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .tracking(2.2)
                        .foregroundStyle(.white.opacity(0.88))
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: Helpers

    private var displayRef: String {
        if let kind, kind.lowercased().contains("qur") {
            return "AL QURAN \(prettyQuranRef(ref))"
        }
        if let kind, !kind.isEmpty {
            return "\(kind) \(ref)".uppercased()
        }
        return ref.uppercased()
    }

    private var hadithRefLabel: String {
        let k = (kind ?? "HADITH").uppercased()
        if k.contains("BUKHARI") { return "SAHIH AL-BUKHARI \(ref)".uppercased() }
        if k.contains("MUSLIM") { return "SAHIH MUSLIM \(ref)".uppercased() }
        return "\(k) \(ref)".uppercased()
    }

    /// Short Arabic for teal header (chapter-style); long Arabic goes to body.
    private var hadithHeaderArabic: String? {
        guard showArabic, !arabic.isEmpty else { return nil }
        return arabic.count <= 90 ? arabic : nil
    }

    private var hadithEnglishHeader: String? {
        if let title, !title.isEmpty { return title }
        return nil
    }

    private var hadithBodyText: String? {
        if showEnglish, !english.isEmpty {
            return trimmedBody(english, limit: 520)
        }
        if showUrdu, !urdu.isEmpty {
            return trimmedBody(urdu, limit: 420)
        }
        if showArabic, !arabic.isEmpty, arabic.count > 90 {
            return trimmedBody(arabic, limit: 360)
        }
        return nil
    }

    private var usesClassicCallUponLayout: Bool {
        let body = showEnglish ? english : ""
        return body.localizedCaseInsensitiveContains("call upon")
            || ref.contains("40:60")
            || body.localizedCaseInsensitiveContains("respond to you")
    }

    private var reminderHook: (eyebrow: String, headline: String)? {
        if usesClassicCallUponLayout { return nil }
        if let title, !title.isEmpty {
            let words = title.split(separator: " ")
            if words.count >= 2 {
                let mid = max(1, words.count / 2)
                return (
                    words.prefix(mid).joined(separator: " ").uppercased(),
                    words.suffix(from: mid).joined(separator: " ").uppercased()
                )
            }
            return ("REMINDER", title.uppercased())
        }
        return ("REMINDER", "FROM BE UMMATI")
    }

    private var reminderAccentLine: String? {
        if usesClassicCallUponLayout { return "I will respond to you." }
        let body = showEnglish ? english : ""
        if body.localizedCaseInsensitiveContains("respond") {
            return "I will respond to you."
        }
        return nil
    }

    private var reminderBullets: [String] {
        let raw: String
        if showEnglish, !english.isEmpty { raw = english }
        else if showUrdu, !urdu.isEmpty { raw = urdu }
        else if showArabic, !arabic.isEmpty { raw = arabic }
        else { raw = title ?? ref }

        let cleaned = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var lines = cleaned
            .components(separatedBy: CharacterSet(charactersIn: "\n•"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count == 1 {
            lines = softWrapLines(lines[0], maxLen: 38, maxLines: 7)
        }
        return Array(lines.prefix(7))
    }

    private func arabicFontSize(for text: String) -> CGFloat {
        let n = text.count
        if n < 60 { return 34 }
        if n < 120 { return 28 }
        if n < 200 { return 24 }
        return 20
    }

    private func prettyQuranRef(_ ref: String) -> String {
        if ref.localizedCaseInsensitiveContains("surah") { return ref }
        return "SURAH \(ref)"
    }

    private func trimmedBody(_ text: String, limit: Int) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > limit else { return t }
        let idx = t.index(t.startIndex, offsetBy: limit)
        var cut = String(t[..<idx])
        if let last = cut.lastIndex(of: " ") {
            cut = String(cut[..<last])
        }
        return cut + "…"
    }

    private func softWrapLines(_ text: String, maxLen: Int, maxLines: Int) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var current = ""
        for w in words {
            let next = current.isEmpty ? w : current + " " + w
            if next.count > maxLen, !current.isEmpty {
                lines.append(current)
                current = w
                if lines.count >= maxLines { break }
            } else {
                current = next
            }
        }
        if !current.isEmpty, lines.count < maxLines {
            lines.append(current)
        }
        return lines
    }
}

// MARK: - Transfer + button / sheet

private struct ShareablePNG: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}

struct ShareCardButton: View {
    @EnvironmentObject var reading: ReadingSettings
    var title: String? = nil
    var kind: String? = nil
    let ref: String
    let arabic: String
    let english: String
    let urdu: String

    @State private var showStudio = false

    var body: some View {
        Button {
            showStudio = true
        } label: {
            Label("Card", systemImage: "photo.on.rectangle.angled")
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showStudio) {
            ShareCardStudioView(
                title: title,
                kind: kind,
                ref: ref,
                arabic: arabic,
                english: english,
                urdu: urdu,
                mode: .image
            )
            .environmentObject(reading)
        }
    }
}

enum ShareStudioMode {
    case image
    case text
}

/// Preview + language / chrome options + optional text crop + share.
struct ShareCardStudioView: View {
    @EnvironmentObject var reading: ReadingSettings
    @Environment(\.dismiss) private var dismiss

    var title: String? = nil
    var kind: String? = nil
    let ref: String
    let arabic: String
    let english: String
    let urdu: String
    var mode: ShareStudioMode = .image

    @State private var style: ShareCardStyle = .dailyQuran
    @State private var theme: ShareCardTheme = .classic

    // Include languages (any combination)
    @State private var includeArabic = true
    @State private var includeEnglish = true
    @State private var includeUrdu = true

    // Extra chrome
    @State private var includeReference = true
    @State private var includeBrand = true
    @State private var includeSlogan = true
    @State private var includeTitle = true

    // Editable crop (defaults to full source text)
    @State private var cropArabic = ""
    @State private var cropEnglish = ""
    @State private var cropUrdu = ""
    @State private var showCropEditors = false

    @State private var payload: ShareablePNG?
    @State private var preview: UIImage?
    @State private var preparing = false

    private var hasArabic: Bool { !arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasEnglish: Bool { !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasUrdu: Bool { !urdu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private var effectiveArabic: String { cropArabic.isEmpty ? arabic : cropArabic }
    private var effectiveEnglish: String { cropEnglish.isEmpty ? english : cropEnglish }
    private var effectiveUrdu: String { cropUrdu.isEmpty ? urdu : cropUrdu }

    private var shareTextBody: String {
        ShareText.compose(
            title: includeTitle ? title : nil,
            kind: kind,
            ref: includeReference ? ref : (kind ?? ""),
            arabic: effectiveArabic,
            english: effectiveEnglish,
            urdu: effectiveUrdu,
            shareArabic: includeArabic && hasArabic,
            shareEnglish: includeEnglish && hasEnglish,
            shareUrdu: includeUrdu && hasUrdu
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if mode == .image {
                        sectionHeader("Template")
                        Picker("Style", selection: $style) {
                            ForEach(ShareCardStyle.allCases) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        sectionHeader("Themes")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ShareCardTheme.allCases) { t in
                                    themeChip(t)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    sectionHeader("Include languages")
                    VStack(spacing: 0) {
                        languageRow("Arabic", systemImage: "character.textbox", isOn: $includeArabic, available: hasArabic)
                        Divider().padding(.leading, 44)
                        languageRow("English", systemImage: "textformat.abc", isOn: $includeEnglish, available: hasEnglish)
                        Divider().padding(.leading, 44)
                        languageRow("Urdu", systemImage: "character", isOn: $includeUrdu, available: hasUrdu)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)

                    HStack(spacing: 10) {
                        quickLangButton("All") {
                            if hasArabic { includeArabic = true }
                            if hasEnglish { includeEnglish = true }
                            if hasUrdu { includeUrdu = true }
                        }
                        quickLangButton("Arabic only") {
                            includeArabic = hasArabic
                            includeEnglish = false
                            includeUrdu = false
                        }
                        quickLangButton("EN + UR") {
                            includeArabic = false
                            includeEnglish = hasEnglish
                            includeUrdu = hasUrdu
                        }
                    }
                    .padding(.horizontal)

                    sectionHeader("On the card")
                    VStack(spacing: 0) {
                        toggleRow("Reference", isOn: $includeReference)
                        Divider().padding(.leading, 16)
                        toggleRow("Title", isOn: $includeTitle)
                        if mode == .image {
                            Divider().padding(.leading, 16)
                            toggleRow("Be Ummati badge", isOn: $includeBrand)
                            Divider().padding(.leading, 16)
                            toggleRow("Side slogan", isOn: $includeSlogan)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)

                    DisclosureGroup(isExpanded: $showCropEditors) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Edit or shorten any language before sharing. Changes update the preview live.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if hasArabic {
                                cropEditor(label: "Arabic", text: $cropArabic, full: arabic, reset: {
                                    cropArabic = arabic
                                })
                            }
                            if hasEnglish {
                                cropEditor(label: "English", text: $cropEnglish, full: english, reset: {
                                    cropEnglish = english
                                })
                            }
                            if hasUrdu {
                                cropEditor(label: "Urdu", text: $cropUrdu, full: urdu, reset: {
                                    cropUrdu = urdu
                                })
                            }

                            HStack {
                                Button("Reset all to full") {
                                    cropArabic = arabic
                                    cropEnglish = english
                                    cropUrdu = urdu
                                }
                                .font(.subheadline.weight(.semibold))
                                Spacer()
                                Button("Clear crops") {
                                    cropArabic = arabic
                                    cropEnglish = english
                                    cropUrdu = urdu
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Label("Custom text / crop", systemImage: "scissors")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal)
                    .onChange(of: showCropEditors) { _, open in
                        guard open else { return }
                        if cropArabic.isEmpty { cropArabic = arabic }
                        if cropEnglish.isEmpty { cropEnglish = english }
                        if cropUrdu.isEmpty { cropUrdu = urdu }
                    }

                    if mode == .image {
                        if preparing {
                            ProgressView("Rendering…")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else if let preview {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                                .padding(.horizontal, 20)
                        }

                        if let payload, let preview {
                            ShareLink(
                                item: payload,
                                preview: SharePreview(ref, image: Image(uiImage: preview))
                            ) {
                                Label("Share image", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(BeUmmatiShare.brandRed, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 20)
                        }
                    } else {
                        Text(shareTextBody)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal)

                        ShareLink(item: shareTextBody) {
                            Label("Share text", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(BeUmmatiShare.brandRed, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                    }

                    Button("Save language choices as default") {
                        reading.shareArabic = includeArabic
                        reading.shareEnglish = includeEnglish
                        reading.shareUrdu = includeUrdu
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(mode == .image ? "Share card" : "Share text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                style = ShareCardStyle.preferred(for: kind)
                includeArabic = reading.shareArabic && hasArabic
                includeEnglish = reading.shareEnglish && hasEnglish
                includeUrdu = reading.shareUrdu && hasUrdu
                // If defaults hid everything available, turn on all available.
                if !includeArabic && !includeEnglish && !includeUrdu {
                    includeArabic = hasArabic
                    includeEnglish = hasEnglish
                    includeUrdu = hasUrdu
                }
                cropArabic = ""
                cropEnglish = ""
                cropUrdu = ""
                render()
            }
            .onChange(of: style) { _, _ in render() }
            .onChange(of: theme) { _, _ in render() }
            .onChange(of: includeArabic) { _, _ in render() }
            .onChange(of: includeEnglish) { _, _ in render() }
            .onChange(of: includeUrdu) { _, _ in render() }
            .onChange(of: includeReference) { _, _ in render() }
            .onChange(of: includeBrand) { _, _ in render() }
            .onChange(of: includeSlogan) { _, _ in render() }
            .onChange(of: includeTitle) { _, _ in render() }
            .onChange(of: cropArabic) { _, _ in render() }
            .onChange(of: cropEnglish) { _, _ in render() }
            .onChange(of: cropUrdu) { _, _ in render() }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .tracking(0.8)
            .padding(.horizontal, 20)
            .padding(.top, 4)
    }

    private func languageRow(_ title: String, systemImage: String, isOn: Binding<Bool>, available: Bool) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
        }
        .disabled(!available)
        .opacity(available ? 1 : 0.45)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
    }

    private func quickLangButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func themeChip(_ t: ShareCardTheme) -> some View {
        let selected = theme == t
        return Button {
            theme = t
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: t.swatch,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(selected ? BeUmmatiShare.brandRed : Color.clear, lineWidth: 2.5)
                        .frame(width: 50, height: 50)
                )
                Text(t.label)
                    .font(.caption2.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(t.label) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func cropEditor(label: String, text: Binding<String>, full: String, reset: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(text.wrappedValue.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Full", action: reset)
                    .font(.caption.weight(.semibold))
            }
            TextEditor(text: text)
                .frame(minHeight: 88, maxHeight: 140)
                .padding(6)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    @MainActor
    private func render() {
        guard mode == .image else { return }
        preparing = true
        payload = nil
        preview = nil

        let card = ShareCardView(
            style: style,
            theme: theme,
            title: includeTitle ? title : nil,
            kind: kind,
            ref: includeReference ? ref : "",
            arabic: effectiveArabic,
            english: effectiveEnglish,
            urdu: effectiveUrdu,
            showArabic: includeArabic && hasArabic,
            showEnglish: includeEnglish && hasEnglish,
            showUrdu: includeUrdu && hasUrdu,
            showBrand: includeBrand,
            showSlogan: includeSlogan,
            showReference: includeReference
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage, let data = ui.pngData() {
            payload = ShareablePNG(data: data)
            preview = ui
        }
        preparing = false
    }
}


/// Text share framed as a gift (Messages / Mail / etc.).
struct GiftReminderButton: View {
    @EnvironmentObject var reading: ReadingSettings
    var title: String? = nil
    let kind: String
    let ref: String
    let arabic: String
    let english: String
    let urdu: String

    private var message: String {
        let body = ShareText.compose(
            title: title,
            kind: kind,
            ref: ref,
            arabic: arabic,
            english: english,
            urdu: urdu,
            reading: reading
        )
        return "A reminder for you\n\n\(body)"
    }

    var body: some View {
        ShareLink(item: message) {
            Label("Gift", systemImage: "gift")
        }
    }
}
