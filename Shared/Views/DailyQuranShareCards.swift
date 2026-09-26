import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Canvas (Instagram 4:5 — matches Android DailyQuranLab 1080×1350)

enum DQShare {
    static let W: CGFloat = 1080
    static let H: CGFloat = 1350

    static func color(_ hex: UInt32, alpha: Double = 1) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    static func uthmani(_ size: CGFloat) -> Font {
        for name in ["KFGQPCHAFSUthmanicScript-Regula", "me_quran2", "Amiri-Regular"] {
            if UIFont(name: name, size: size) != nil { return .custom(name, size: size) }
        }
        return .system(size: size)
    }

    static func nastaliq(_ size: CGFloat) -> Font {
        for name in ["NotoNastaliqUrdu-Regular", "MehrNastaliqWeb", "Gulzar-Regular"] {
            if UIFont(name: name, size: size) != nil { return .custom(name, size: size) }
        }
        return .system(size: size)
    }

    static func serif(_ size: CGFloat, bold: Bool = false) -> Font {
        if UIFont(name: "InstrumentSerif-Regular", size: size) != nil {
            return .custom("InstrumentSerif-Regular", size: size)
        }
        if UIFont(name: "Fraunces-Regular", size: size) != nil {
            return .custom("Fraunces-Regular", size: size)
        }
        return .system(size: size, weight: bold ? .semibold : .regular, design: .serif)
    }

    static func sans(_ size: CGFloat, bold: Bool = false) -> Font {
        .system(size: size, weight: bold ? .bold : .regular, design: .rounded)
    }

    /// Strip tashkeel for length / fit decisions.
    static func bareLength(_ arabic: String) -> Int {
        let stripped = arabic.unicodeScalars.filter { s in
            let v = s.value
            return !(v >= 0x064B && v <= 0x065F) && v != 0x0670
        }
        return stripped.count
    }

    static func tier(_ arabic: String) -> Int {
        let n = bareLength(arabic)
        if n <= 70 { return 0 }
        if n <= 150 { return 1 }
        return 2
    }

    /// Prefer translation-only when ayah is very long.
    static func translationOnly(arabic: String, english: String) -> Bool {
        bareLength(arabic) > 280 || english.count > 400
    }

    static func sizes(_ tier: Int) -> (ar: CGFloat, ur: CGFloat, en: CGFloat) {
        switch tier {
        case 0: return (78, 46, 34)
        case 1: return (60, 38, 30)
        default: return (46, 30, 26)
        }
    }
}

// MARK: - Style enum (1:1 with Android ShareTemplate)

enum ShareCardStyle: String, CaseIterable, Identifiable {
    case mihrab
    case folio
    case fajr
    case kuficCircuit
    case inkBloom
    case zellijStack
    case jadeVelvet
    case cyanotype
    case basalt
    case nacre
    case terrazzoBone
    case oxbloodTazhib
    case contourTide
    case risoDuo
    case nightGirih
    case keystone
    case datum
    case masthead
    case cascade
    case signal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mihrab: return "Mihrab"
        case .folio: return "Folio"
        case .fajr: return "Fajr"
        case .kuficCircuit: return "Kufic"
        case .inkBloom: return "Ink bloom"
        case .zellijStack: return "Zellij"
        case .jadeVelvet: return "Jade"
        case .cyanotype: return "Cyanotype"
        case .basalt: return "Basalt"
        case .nacre: return "Nacre"
        case .terrazzoBone: return "Terrazzo"
        case .oxbloodTazhib: return "Oxblood"
        case .contourTide: return "Contour"
        case .risoDuo: return "Riso"
        case .nightGirih: return "Girih"
        case .keystone: return "Keystone"
        case .datum: return "Datum"
        case .masthead: return "Masthead"
        case .cascade: return "Cascade"
        case .signal: return "Signal"
        }
    }

    var blurb: String {
        switch self {
        case .mihrab: return "Lit prayer niche with brass"
        case .folio: return "Stone wall + emerald slab"
        case .fajr: return "Pre-dawn sky and dunes"
        case .kuficCircuit: return "Dark lattice, technical geometry"
        case .inkBloom: return "Indigo wash on paper"
        case .zellijStack: return "Moroccan tile colour bands"
        case .jadeVelvet: return "Deep jade + champagne type"
        case .cyanotype: return "Prussian blue sun-print"
        case .basalt: return "Brutalist cut stone"
        case .nacre: return "Soft pearl iridescence"
        case .terrazzoBone: return "Speckled bone slab"
        case .oxbloodTazhib: return "Manuscript gold corners"
        case .contourTide: return "Topographic petrol lines"
        case .risoDuo: return "Cobalt + tangerine print"
        case .nightGirih: return "Midnight geometry constellation"
        case .keystone: return "Header strip · accent rail · info panel"
        case .datum: return "Side rail · numbered translation stack"
        case .masthead: return "Editorial rules · display reference"
        case .cascade: return "Stepped colour bands · layered read"
        case .signal: return "Badge · bold bar · poster hierarchy"
        }
    }

    /// Tiny swatch for the studio picker.
    var swatch: [Color] {
        switch self {
        case .mihrab: return [DQShare.color(0x16302A), DQShare.color(0xC79A4B), DQShare.color(0x060D0C)]
        case .folio: return [DQShare.color(0xE9E4D8), DQShare.color(0x0B5A45), DQShare.color(0x141A18)]
        case .fajr: return [DQShare.color(0x061021), DQShare.color(0x2A5568), DQShare.color(0xE2A74E)]
        case .kuficCircuit: return [DQShare.color(0x0B1220), DQShare.color(0xC9A24A), DQShare.color(0xF2F4F8)]
        case .inkBloom: return [DQShare.color(0xF4F1EA), DQShare.color(0x2B3A67), DQShare.color(0xB23A2E)]
        case .zellijStack: return [DQShare.color(0x1B4B8F), DQShare.color(0xD99A2B), DQShare.color(0x14634F)]
        case .jadeVelvet: return [DQShare.color(0x14543E), DQShare.color(0xE7D7A8), DQShare.color(0x06231C)]
        case .cyanotype: return [DQShare.color(0x0A2A43), DQShare.color(0xCBD9E2), DQShare.color(0xD9A441)]
        case .basalt: return [DQShare.color(0x1C1C1A), DQShare.color(0xE6E3DC), DQShare.color(0x8A9A5B)]
        case .nacre: return [DQShare.color(0xEFF4F3), DQShare.color(0xCFE7DF), DQShare.color(0xB79A5B)]
        case .terrazzoBone: return [DQShare.color(0xF1EDE4), DQShare.color(0x2E6B55), DQShare.color(0x8C3A32)]
        case .oxbloodTazhib: return [DQShare.color(0x4A0F16), DQShare.color(0xD4AF5A), DQShare.color(0xF0E6D2)]
        case .contourTide: return [DQShare.color(0x041F25), DQShare.color(0x7FE0C4), DQShare.color(0xF2C879)]
        case .risoDuo: return [DQShare.color(0x2B3EE0), DQShare.color(0xFF5A36), DQShare.color(0xFAF7F0)]
        case .nightGirih: return [DQShare.color(0x060A18), DQShare.color(0xE0B95F), DQShare.color(0x9AA7C7)]
        case .keystone: return [DQShare.color(0x12151A), DQShare.color(0xC9A24A), DQShare.color(0xE8E4DB)]
        case .datum: return [DQShare.color(0x0E1A1F), DQShare.color(0x5EE0B5), DQShare.color(0xF2EDE1)]
        case .masthead: return [DQShare.color(0xF7F4EE), DQShare.color(0x1A1A1A), DQShare.color(0x8B1E1E)]
        case .cascade: return [DQShare.color(0x0B3D2E), DQShare.color(0xE7D7A8), DQShare.color(0x14543E)]
        case .signal: return [DQShare.color(0x0A1628), DQShare.color(0xD4A017), DQShare.color(0xE8DCC8)]
        }
    }

    static func preferred(for kind: String?) -> ShareCardStyle {
        _ = kind
        return .mihrab
    }
}

// MARK: - Colour mood (post-render grade — same set as Android ShareColorMood)

enum ShareColorMood: String, CaseIterable, Identifiable {
    case `default`, warm, cool, gold, emerald, rose, midnight, sand, mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default: return "Default"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .gold: return "Gold"
        case .emerald: return "Emerald"
        case .rose: return "Rose"
        case .midnight: return "Midnight"
        case .sand: return "Sand"
        case .mono: return "Mono"
        }
    }

    var swatch: Color {
        switch self {
        case .default: return Color(white: 0.55)
        case .warm: return DQShare.color(0xC47A3A)
        case .cool: return DQShare.color(0x3A7AB8)
        case .gold: return DQShare.color(0xD4AF5A)
        case .emerald: return DQShare.color(0x1B6B4A)
        case .rose: return DQShare.color(0xB23A5A)
        case .midnight: return DQShare.color(0x1A2744)
        case .sand: return DQShare.color(0xD8C9A8)
        case .mono: return Color(white: 0.18)
        }
    }

    /// Hue in radians for CIHueAdjust; nil = skip.
    private var hueRadians: NSNumber? {
        switch self {
        case .default: return nil
        case .warm: return NSNumber(value: -18.0 * .pi / 180)
        case .cool: return NSNumber(value: 22.0 * .pi / 180)
        case .gold: return NSNumber(value: -28.0 * .pi / 180)
        case .emerald: return NSNumber(value: 95.0 * .pi / 180)
        case .rose: return NSNumber(value: -48.0 * .pi / 180)
        case .midnight: return NSNumber(value: 205.0 * .pi / 180)
        case .sand: return NSNumber(value: -10.0 * .pi / 180)
        case .mono: return nil
        }
    }

    private var saturation: Float {
        switch self {
        case .default: return 1
        case .warm: return 1.12
        case .cool: return 1.08
        case .gold: return 1.22
        case .emerald: return 1.15
        case .rose: return 1.18
        case .midnight: return 0.92
        case .sand: return 0.62
        case .mono: return 0
        }
    }

    private var wash: UIColor? {
        switch self {
        case .default: return nil
        case .warm: return UIColor(red: 0.77, green: 0.48, blue: 0.23, alpha: 0.22)
        case .cool: return UIColor(red: 0.23, green: 0.48, blue: 0.72, alpha: 0.19)
        case .gold: return UIColor(red: 0.83, green: 0.69, blue: 0.35, alpha: 0.25)
        case .emerald: return UIColor(red: 0.11, green: 0.42, blue: 0.29, alpha: 0.21)
        case .rose: return UIColor(red: 0.70, green: 0.23, blue: 0.35, alpha: 0.22)
        case .midnight: return UIColor(red: 0.07, green: 0.10, blue: 0.18, alpha: 0.33)
        case .sand: return UIColor(red: 0.91, green: 0.86, blue: 0.78, alpha: 0.21)
        case .mono: return nil
        }
    }

    func apply(to image: UIImage) -> UIImage {
        guard self != .default, let cg = image.cgImage else { return image }
        let ci = CIImage(cgImage: cg)
        var current = ci
        if saturation != 1 {
            let f = CIFilter(name: "CIColorControls")
            f?.setValue(current, forKey: kCIInputImageKey)
            f?.setValue(saturation, forKey: kCIInputSaturationKey)
            if let out = f?.outputImage { current = out }
        }
        if let hue = hueRadians {
            let f = CIFilter(name: "CIHueAdjust")
            f?.setValue(current, forKey: kCIInputImageKey)
            f?.setValue(hue, forKey: kCIInputAngleKey)
            if let out = f?.outputImage { current = out }
        }
        let ctx = CIContext(options: nil)
        guard let graded = ctx.createCGImage(current, from: current.extent) else { return image }
        var ui = UIImage(cgImage: graded, scale: image.scale, orientation: image.imageOrientation)
        if let wash {
            ui = ui.softLightOverlay(wash)
        }
        return ui
    }
}

private extension UIImage {
    func softLightOverlay(_ color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
            color.setFill()
            // Overlay is widely available (incl. Mac Catalyst); softLight skips on some paths.
            UIRectFillUsingBlendMode(CGRect(origin: .zero, size: size), .overlay)
        }
    }
}

// MARK: - Real colour palette (text / bg / logo — not a saturation grade)

struct SharePalette: Equatable {
    var background: Color? = nil
    var arabic: Color? = nil
    var english: Color? = nil
    var urdu: Color? = nil
    var reference: Color? = nil
    var brand: Color? = nil
    var brandText: String = "BE UMMATI"

    var usesFlatBackground: Bool { background != nil }

    /// True when a background tint is applied on top of the template (design stays).
    var hasBackgroundTint: Bool { background != nil }

    static let design = SharePalette()

    static let presets: [(label: String, palette: SharePalette)] = [
        ("Design", .design),
        ("Night", SharePalette(
            background: DQShare.color(0x0B1220),
            arabic: DQShare.color(0xF2F4F8),
            english: DQShare.color(0xC9A24A),
            urdu: DQShare.color(0xCBD9E2),
            reference: DQShare.color(0x93A0B8),
            brand: DQShare.color(0xC9A24A)
        )),
        ("Ivory", SharePalette(
            background: DQShare.color(0xF4F1EA),
            arabic: DQShare.color(0x14161A),
            english: DQShare.color(0x2B3A67),
            urdu: DQShare.color(0x1A1A1A),
            reference: DQShare.color(0x6C7570),
            brand: DQShare.color(0xB23A2E)
        )),
        ("Emerald", SharePalette(
            background: DQShare.color(0x0B5A45),
            arabic: DQShare.color(0xE7D7A8),
            english: DQShare.color(0xF2EDE1),
            urdu: DQShare.color(0xC4CFC6),
            reference: DQShare.color(0x9BC3AE),
            brand: DQShare.color(0xE7D7A8)
        )),
        ("Brass", SharePalette(
            background: DQShare.color(0x1A1208),
            arabic: DQShare.color(0xE7D7A8),
            english: DQShare.color(0xC79A4B),
            urdu: DQShare.color(0xD8C9A8),
            reference: DQShare.color(0xA89060),
            brand: DQShare.color(0xC79A4B)
        )),
        ("Rose", SharePalette(
            background: DQShare.color(0x4A0F16),
            arabic: DQShare.color(0xF0E6D2),
            english: DQShare.color(0xD4AF5A),
            urdu: DQShare.color(0xE8DCC8),
            reference: DQShare.color(0xC9A24A),
            brand: DQShare.color(0xD4AF5A)
        )),
        ("Ocean", SharePalette(
            background: DQShare.color(0x0A2A43),
            arabic: DQShare.color(0xF7F9FA),
            english: DQShare.color(0xD9A441),
            urdu: DQShare.color(0xCBD9E2),
            reference: DQShare.color(0x7FE0C4),
            brand: DQShare.color(0xCBD9E2)
        ))
    ]

    static let swatches: [Color] = [
        DQShare.color(0xF2EDE1), DQShare.color(0xF4F1EA), DQShare.color(0xE6E3DC), DQShare.color(0xCBD9E2),
        DQShare.color(0x14161A), DQShare.color(0x0B1220), DQShare.color(0x060D0C), DQShare.color(0x4A0F16),
        DQShare.color(0x0B5A45), DQShare.color(0x0A2A43), DQShare.color(0x1B4B8F), DQShare.color(0x2B3EE0),
        DQShare.color(0xC79A4B), DQShare.color(0xD4AF5A), DQShare.color(0xB23A2E), DQShare.color(0xFF5A36)
    ]
}

// MARK: - Main card

struct DailyQuranShareCard: View {
    let style: ShareCardStyle
    let arabic: String
    let english: String
    let urdu: String
    let reference: String
    var showArabic: Bool = true
    var showEnglish: Bool = true
    var showUrdu: Bool = true
    var showBrand: Bool = true
    var showReference: Bool = true
    var palette: SharePalette = .design

    private var fitHideArabic: Bool {
        DQShare.translationOnly(arabic: arabic, english: english) && showEnglish
    }

    private var ar: String { (showArabic && !fitHideArabic) ? arabic : "" }
    private var en: String { showEnglish ? english : "" }
    private var ur: String { showUrdu ? urdu : "" }
    private var ref: String { showReference ? reference : "" }
    private var tier: Int { DQShare.tier(ar.isEmpty ? arabic : ar) }
    private var sz: (ar: CGFloat, ur: CGFloat, en: CGFloat) { DQShare.sizes(tier) }

    var body: some View {
        ZStack {
            // Always keep the template design; colour presets / BG only recolour it.
            switch style {
            case .mihrab: mihrab
            case .folio: folio
            case .fajr: fajr
            case .kuficCircuit: kufic
            case .inkBloom: inkBloom
            case .zellijStack: zellij
            case .jadeVelvet: jade
            case .cyanotype: cyanotype
            case .basalt: basalt
            case .nacre: nacre
            case .terrazzoBone: terrazzo
            case .oxbloodTazhib: oxblood
            case .contourTide: contour
            case .risoDuo: riso
            case .nightGirih: girih
            case .keystone: keystone
            case .datum: datum
            case .masthead: masthead
            case .cascade: cascade
            case .signal: signal
            }

            // Tint atmosphere toward the chosen background; keep ornaments + text colours.
            if let bg = palette.background {
                bg
                    .opacity(0.48)
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: DQShare.W, height: DQShare.H)
        .clipped()
    }

    // MARK: Mihrab

    private var mihrab: some View {
        let brass = DQShare.color(0xC79A4B)
        let bone = DQShare.color(0xF2EDE1)
        let sage = DQShare.color(0xC4CFC6)
        return ZStack {
            LinearGradient(colors: [DQShare.color(0x060D0C), DQShare.color(0x0A1412)], startPoint: .top, endPoint: .bottom)
            MihrabArch()
                .fill(
                    LinearGradient(
                        colors: [DQShare.color(0x16302A), DQShare.color(0x0D1B18), DQShare.color(0x0A1614)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            MihrabArch()
                .stroke(brass.opacity(0.38), lineWidth: 2.5)
            RadialGradient(
                colors: [DQShare.color(0x2A5B4C, alpha: 0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.35),
                startRadius: 40, endRadius: 620
            )
            .clipShape(MihrabArch())

            VStack(spacing: 0) {
                if tier < 2 && !ar.isEmpty {
                    OctagonStar()
                        .stroke(brass.opacity(0.7), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .padding(.top, 170)
                    Text("AYAH OF THE DAY")
                        .font(DQShare.sans(20, bold: true))
                        .tracking(5.5)
                        .foregroundStyle(brass)
                        .padding(.top, 18)
                } else {
                    Spacer().frame(height: 200)
                }
                Spacer(minLength: 20)
                centeredStack(
                    arColor: bone, urColor: bone, enColor: sage,
                    sep: brass, showSep: tier < 2,
                    maxWidth: 780
                )
                .padding(.horizontal, 150)
                Spacer(minLength: 20)
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(20, bold: true))
                        .tracking(3.5)
                        .foregroundStyle(brass)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }
                if showBrand {
                    brandLine(bone.opacity(0.43))
                        .padding(.bottom, 36)
                } else {
                    Spacer().frame(height: 48)
                }
            }
        }
    }

    // MARK: Folio

    private var folio: some View {
        let ink = DQShare.color(0x141A18)
        let emerald = DQShare.color(0x0B5A45)
        let bone = DQShare.color(0xFBF8F1)
        let slate = DQShare.color(0x6C7570)
        let slabY: CGFloat = tier >= 2 ? 1000 : 1040
        return ZStack(alignment: .topLeading) {
            DQShare.color(0xE9E4D8)
            Circle()
                .fill(DQShare.color(0xDCD5C5))
                .frame(width: 860, height: 860)
                .position(x: 880, y: 400)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(colors: [emerald, DQShare.color(0x073B2E)], startPoint: .top, endPoint: .bottom)
                    .frame(height: DQShare.H - slabY)
            }
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(emerald)
                .frame(width: 76, height: 76)
                .overlay(Text("ب").font(DQShare.uthmani(36)).foregroundStyle(bone))
                .padding(.leading, 72)
                .padding(.top, 72)

            if !ref.isEmpty {
                Text(ref.uppercased())
                    .font(DQShare.sans(18, bold: true))
                    .tracking(3)
                    .foregroundStyle(slate)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 72)
                    .padding(.top, 100)
            }

            VStack(alignment: .trailing, spacing: 28) {
                if !ar.isEmpty {
                    Text(ar)
                        .font(DQShare.uthmani(sz.ar))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.7)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                if !ur.isEmpty {
                    Text(ur)
                        .font(DQShare.nastaliq(sz.ur))
                        .foregroundStyle(ink.opacity(0.82))
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(8)
                        .minimumScaleFactor(0.72)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }
            .frame(maxWidth: 820, alignment: .trailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 72)
            .padding(.top, tier == 0 ? 380 : 260)
            .padding(.bottom, DQShare.H - slabY + 40)

            if !en.isEmpty {
                Text(en)
                    .font(DQShare.serif(sz.en))
                    .foregroundStyle(bone)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: 780, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 72)
                    .padding(.bottom, 100)
            }

            if showBrand {
                Text("BE UMMATI")
                    .font(DQShare.sans(16, bold: true))
                    .tracking(4)
                    .foregroundStyle(bone.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 72)
                    .padding(.bottom, 42)
            }
        }
    }

    // MARK: Fajr

    private var fajr: some View {
        let amber = DQShare.color(0xE2A74E)
        let light = DQShare.color(0xF5F1E8)
        let mute = DQShare.color(0xC6D3DC)
        let discCy: CGFloat = tier >= 2 ? 400 : 480
        let discR: CGFloat = tier >= 2 ? 220 : 280
        let washTop: CGFloat = tier >= 2 ? 860 : 980
        return ZStack {
            LinearGradient(
                stops: [
                    .init(color: DQShare.color(0x061021), location: 0),
                    .init(color: DQShare.color(0x0B1B33), location: 0.32),
                    .init(color: DQShare.color(0x17364C), location: 0.58),
                    .init(color: DQShare.color(0x2A5568), location: 0.78),
                    .init(color: DQShare.color(0x345F6E), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(RadialGradient(colors: [DQShare.color(0xF6D9A4, alpha: 0.11), .clear], center: .center, startRadius: 10, endRadius: discR))
                .frame(width: discR * 2, height: discR * 2)
                .position(x: 540, y: discCy)
            Circle()
                .stroke(amber.opacity(0.26), lineWidth: 2)
                .frame(width: discR * 2, height: discR * 2)
                .position(x: 540, y: discCy)

            FajrDune()
                .fill(DQShare.color(0x061021, alpha: 0.7))

            if !ref.isEmpty {
                Text(ref.uppercased())
                    .font(DQShare.sans(18, bold: true))
                    .tracking(4)
                    .foregroundStyle(amber)
                    .padding(.top, 88)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if !ar.isEmpty {
                Text(ar)
                    .font(DQShare.uthmani(sz.ar))
                    .foregroundStyle(light)
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .minimumScaleFactor(0.65)
                    .frame(width: 780)
                    .position(x: 540, y: discCy)
            }

            VStack(spacing: 14) {
                Spacer()
                if !ur.isEmpty {
                    Text(ur)
                        .font(DQShare.nastaliq(sz.ur))
                        .foregroundStyle(light.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: 800)
                }
                if !en.isEmpty {
                    Text(en)
                        .font(DQShare.serif(sz.en))
                        .foregroundStyle(mute)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: 720)
                }
                if showBrand {
                    brandLine(light.opacity(0.4))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 100)
            .padding(.bottom, 48)
            .padding(.top, washTop)
        }
    }

    // MARK: Kufic

    private var kufic: some View {
        let brass = DQShare.color(0xC9A24A)
        let text = DQShare.color(0xF2F4F8)
        let muted = DQShare.color(0x93A0B8)
        return ZStack(alignment: .leading) {
            DQShare.color(0x0B1220)
            KuficLattice()
                .stroke(DQShare.color(0x6F5A2C, alpha: 0.14), lineWidth: 6)
            Rectangle()
                .fill(brass)
                .frame(width: 6)
                .padding(.leading, 90)

            VStack(alignment: .leading, spacing: 28) {
                if !ar.isEmpty {
                    Text(ar)
                        .font(DQShare.uthmani(sz.ar))
                        .foregroundStyle(text)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.68)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                if !ur.isEmpty {
                    Text(ur)
                        .font(DQShare.nastaliq(sz.ur))
                        .foregroundStyle(text.opacity(0.9))
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(8)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                if !en.isEmpty {
                    Text(en)
                        .font(DQShare.serif(sz.en))
                        .foregroundStyle(muted)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 0)
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(22, bold: true))
                        .tracking(2.5)
                        .foregroundStyle(brass)
                }
            }
            .padding(.leading, 168)
            .padding(.trailing, 96)
            .padding(.top, 180)
            .padding(.bottom, 100)

            if showBrand {
                Text("BE UMMATI")
                    .font(DQShare.sans(18, bold: true))
                    .tracking(4)
                    .foregroundStyle(brass.opacity(0.55))
                    .rotationEffect(.degrees(-90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 28)
                    .padding(.bottom, 160)
            }
        }
    }

    // MARK: Ink bloom

    private var inkBloom: some View {
        let ink = DQShare.color(0x14161A)
        let paper = DQShare.color(0xF4F1EA)
        let seal = DQShare.color(0xB23A2E)
        return ZStack {
            paper
            // Soft indigo blooms — light enough that dark ink stays readable over them.
            Circle().fill(DQShare.color(0x2B3A67, alpha: 0.18)).frame(width: 1040, height: 1040).position(x: 820, y: 980)
            Circle().fill(DQShare.color(0x2B3A67, alpha: 0.10)).frame(width: 680, height: 680).position(x: 700, y: 1100)
            Circle().fill(DQShare.color(0x7E8CB5, alpha: 0.12)).frame(width: 560, height: 560).position(x: 900, y: 850)

            VStack(alignment: .trailing, spacing: 28) {
                if !ar.isEmpty {
                    Text(ar)
                        .font(DQShare.uthmani(sz.ar))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.68)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                if !ur.isEmpty {
                    Text(ur)
                        .font(DQShare.nastaliq(sz.ur))
                        .foregroundStyle(ink.opacity(0.85))
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(8)
                        .minimumScaleFactor(0.7)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 820, alignment: .trailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 100)
            .padding(.top, 200)
            .padding(.bottom, 280)

            if !en.isEmpty {
                Text(en)
                    .font(DQShare.serif(sz.en))
                    .foregroundStyle(ink.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: 700, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 100)
                    .padding(.bottom, 200)
            }

            if showBrand {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(seal)
                    .frame(width: 76, height: 76)
                    .overlay(Text("BU").font(DQShare.sans(22, bold: true)).foregroundStyle(paper))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 72)
                    .padding(.bottom, 64)
            }
            if !ref.isEmpty {
                Text(ref.uppercased())
                    .font(DQShare.sans(18, bold: true))
                    .tracking(2)
                    .foregroundStyle(ink.opacity(0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 80)
                    .padding(.bottom, 80)
            }
        }
    }

    // MARK: Zellij

    private var zellij: some View {
        let ink = DQShare.color(0x1A1A1A)
        let lapis = DQShare.color(0x1B4B8F)
        let clay = DQShare.color(0x7E2B2B)
        let colors: [Color] = [
            DQShare.color(0x1B4B8F), DQShare.color(0xD99A2B),
            DQShare.color(0x7E2B2B), DQShare.color(0x14634F)
        ]
        return ZStack {
            DQShare.color(0xE8E2D4)
            VStack(spacing: 0) {
                zellijBand(colors: colors, height: 280)
                Spacer()
                zellijBand(colors: colors, height: 120)
            }
            VStack(spacing: 16) {
                Spacer().frame(height: 300)
                centeredStack(arColor: ink, urColor: ink, enColor: lapis, sep: clay, showSep: true, maxWidth: 800)
                Spacer()
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(20, bold: true))
                        .tracking(2.8)
                        .foregroundStyle(clay)
                }
                if showBrand { brandLine(ink.opacity(0.55)).padding(.bottom, 28) }
            }
            .padding(.horizontal, 140)
            .padding(.bottom, 140)
        }
    }

    private func zellijBand(colors: [Color], height: CGFloat) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<11, id: \.self) { i in
                ZStack {
                    colors[i % colors.count]
                    OctagonStar()
                        .stroke(DQShare.color(0xE8E2D4).opacity(0.55), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height)
    }

    // MARK: Jade

    private var jade: some View {
        let champagne = DQShare.color(0xE7D7A8)
        let gold = DQShare.color(0xC6A664)
        let mist = DQShare.color(0x9BC3AE)
        return ZStack {
            RadialGradient(
                colors: [DQShare.color(0x14543E), DQShare.color(0x0C3A2C), DQShare.color(0x06231C)],
                center: UnitPoint(x: 0.5, y: 0.32),
                startRadius: 40, endRadius: 900
            )
            VStack(spacing: 18) {
                if showBrand {
                    Text("BE UMMATI")
                        .font(DQShare.sans(18, bold: true))
                        .tracking(6)
                        .foregroundStyle(gold.opacity(0.55))
                        .padding(.top, 64)
                }
                Spacer()
                centeredStack(
                    arColor: champagne, urColor: mist, enColor: champagne,
                    sep: gold, showSep: true, maxWidth: 820,
                    arBoost: 8
                )
                Spacer()
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(22, bold: true))
                        .tracking(3)
                        .foregroundStyle(gold)
                        .padding(.bottom, 70)
                }
            }
            .padding(.horizontal, 130)
        }
    }

    // MARK: Cyanotype

    private var cyanotype: some View {
        let paper = DQShare.color(0xF7F9FA)
        let chalk = DQShare.color(0xCBD9E2)
        let amber = DQShare.color(0xD9A441)
        return ZStack {
            DQShare.color(0x0A2A43)
            Circle().fill(DQShare.color(0x10456B, alpha: 0.35)).frame(width: 760, height: 760).position(x: 300, y: 400)
            Circle().fill(DQShare.color(0x2E6E99, alpha: 0.27)).frame(width: 840, height: 840).position(x: 800, y: 900)
            RoundedRectangle(cornerRadius: 4)
                .stroke(paper.opacity(0.18), lineWidth: 24)
                .padding(24)

            VStack(alignment: .trailing, spacing: 24) {
                if !ar.isEmpty {
                    Text(ar)
                        .font(DQShare.uthmani(sz.ar))
                        .foregroundStyle(paper)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.68)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                if !ur.isEmpty {
                    Text(ur)
                        .font(DQShare.nastaliq(sz.ur))
                        .foregroundStyle(chalk)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(8)
                        .minimumScaleFactor(0.7)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 820, alignment: .trailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.trailing, 100)
            .padding(.top, 180)
            .padding(.bottom, 420)

            if !en.isEmpty {
                Text(en)
                    .font(DQShare.serif(sz.en))
                    .foregroundStyle(paper.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: 700, alignment: .leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 120)
                    .padding(.bottom, 280)
            }

            HStack {
                if showBrand {
                    Text("be ummati")
                        .font(DQShare.sans(16))
                        .tracking(2)
                        .foregroundStyle(chalk.opacity(0.63))
                }
                Spacer()
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(20, bold: true))
                        .tracking(2.4)
                        .foregroundStyle(amber)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 100)
            .padding(.bottom, 60)
        }
    }

    // MARK: Basalt

    private var basalt: some View {
        let bone = DQShare.color(0xE6E3DC)
        let lichen = DQShare.color(0x8A9A5B)
        return ZStack {
            DQShare.color(0x1C1C1A)
            VStack(spacing: 0) {
                basaltSlab(offset: -30).frame(height: 420)
                basaltSlab(offset: 30).frame(height: 500)
                basaltSlab(offset: -30).frame(maxHeight: .infinity)
            }
            VStack(alignment: .trailing, spacing: 24) {
                if showBrand {
                    Text("BE UMMATI")
                        .font(DQShare.sans(18, bold: true))
                        .tracking(4)
                        .foregroundStyle(lichen.opacity(0.59))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 70)
                }
                Spacer().frame(height: 40)
                if !ar.isEmpty {
                    Text(ar)
                        .font(DQShare.uthmani(sz.ar + 14))
                        .foregroundStyle(bone)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.65)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                if !ur.isEmpty {
                    Text(ur)
                        .font(DQShare.nastaliq(sz.ur))
                        .foregroundStyle(bone.opacity(0.9))
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(8)
                        .minimumScaleFactor(0.7)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                Spacer()
                if !en.isEmpty {
                    Text(en)
                        .font(DQShare.serif(sz.en))
                        .foregroundStyle(bone.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(22, bold: true))
                        .tracking(2.8)
                        .foregroundStyle(lichen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 50)
                }
            }
            .padding(.horizontal, 80)
        }
    }

    private func basaltSlab(offset: CGFloat) -> some View {
        ZStack(alignment: .top) {
            DQShare.color(0x262623)
                .offset(x: offset)
            Rectangle()
                .fill(DQShare.color(0x3A3A35))
                .frame(height: 4)
                .offset(x: offset)
        }
    }

    // MARK: Nacre

    private var nacre: some View {
        let ink = DQShare.color(0x23282B)
        let thread = DQShare.color(0xB79A5B)
        return ZStack {
            DQShare.color(0xEFF4F3)
            Circle().fill(DQShare.color(0xCFE7DF, alpha: 0.27)).frame(width: 1000, height: 1000).position(x: 200, y: 300)
            Circle().fill(DQShare.color(0xCBDDF0, alpha: 0.27)).frame(width: 1000, height: 1000).position(x: 480, y: 500)
            Circle().fill(DQShare.color(0xEFD9DE, alpha: 0.27)).frame(width: 1000, height: 1000).position(x: 760, y: 700)
            ForEach(8..<25, id: \.self) { r in
                Circle()
                    .stroke(thread.opacity(0.08), lineWidth: 1)
                    .frame(width: CGFloat(r) * 80, height: CGFloat(r) * 80)
                    .position(x: -100, y: DQShare.H + 100)
            }
            VStack(spacing: 16) {
                if showBrand {
                    Text("be ummati")
                        .font(DQShare.sans(16))
                        .tracking(7)
                        .foregroundStyle(thread)
                        .padding(.top, 70)
                }
                Spacer()
                centeredStack(arColor: ink, urColor: ink, enColor: ink, sep: thread, showSep: true, maxWidth: 760)
                Spacer()
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(20, bold: true))
                        .tracking(2.8)
                        .foregroundStyle(thread)
                        .padding(.bottom, 80)
                }
            }
            .padding(.horizontal, 160)
        }
    }

    // MARK: Terrazzo

    private var terrazzo: some View {
        let bone = DQShare.color(0xF1EDE4)
        let ink = DQShare.color(0x1F2421)
        let chips: [Color] = [
            DQShare.color(0x1F2421), DQShare.color(0x2E6B55), DQShare.color(0x2A4FA3),
            DQShare.color(0xE2A32B), DQShare.color(0x8C3A32)
        ]
        return ZStack {
            bone
            Canvas { ctx, size in
                var rng = SeededGenerator(seed: 7)
                for _ in 0..<180 {
                    let cx = CGFloat.random(in: 0...size.width, using: &rng)
                    let cy = CGFloat.random(in: 0...size.height, using: &rng)
                    if cy > 380 && cy < 980 && cx > 120 && cx < 960 { continue }
                    let r = CGFloat.random(in: 8...26, using: &rng)
                    let col = chips[Int.random(in: 0..<chips.count, using: &rng)]
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                        with: .color(col.opacity(0.78))
                    )
                }
            }
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(bone)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(DQShare.color(0xD8D2C4), lineWidth: 2))
                .frame(width: DQShare.W - 180, height: 660)
                .position(x: 540, y: 650)

            VStack(spacing: 14) {
                Spacer().frame(height: 340)
                centeredStack(arColor: ink, urColor: ink, enColor: ink, sep: ink, showSep: false, maxWidth: 780)
                Spacer()
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(20, bold: true))
                        .tracking(2.4)
                        .foregroundStyle(DQShare.color(0x8C3A32))
                }
            }
            .padding(.horizontal, 140)
            .padding(.bottom, 120)

            if showBrand {
                Circle()
                    .fill(DQShare.color(0x2E6B55))
                    .frame(width: 56, height: 56)
                    .overlay(Text("BU").font(DQShare.sans(16, bold: true)).foregroundStyle(bone))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 62)
                    .padding(.bottom, 62)
            }
        }
    }

    // MARK: Oxblood

    private var oxblood: some View {
        let gold = DQShare.color(0xD4AF5A)
        let goldDim = DQShare.color(0x8C6F2E)
        let ivory = DQShare.color(0xF0E6D2)
        return ZStack {
            LinearGradient(colors: [DQShare.color(0x4A0F16), DQShare.color(0x2E0A0F)], startPoint: .top, endPoint: .bottom)
            RoundedRectangle(cornerRadius: 2)
                .stroke(gold, lineWidth: 2)
                .padding(72)
            RoundedRectangle(cornerRadius: 2)
                .stroke(goldDim, lineWidth: 1)
                .padding(84)
            ForEach([(160.0, 160.0), (920.0, 160.0), (160.0, 1190.0), (920.0, 1190.0)], id: \.0) { p in
                OctagonStar()
                    .stroke(goldDim.opacity(0.85), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .position(x: p.0, y: p.1)
            }
            VStack(spacing: 16) {
                if showBrand {
                    Text("BE UMMATI")
                        .font(DQShare.sans(16, bold: true))
                        .tracking(6)
                        .foregroundStyle(goldDim)
                        .padding(.top, 84)
                }
                Spacer()
                centeredStack(arColor: ivory, urColor: ivory, enColor: gold, sep: gold, showSep: true, maxWidth: 780)
                Spacer()
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(20, bold: true))
                        .tracking(2.8)
                        .foregroundStyle(goldDim)
                        .padding(.bottom, 100)
                }
            }
            .padding(.horizontal, 150)
        }
    }

    // MARK: Contour

    private var contour: some View {
        let mint = DQShare.color(0x7FE0C4)
        let pale = DQShare.color(0xE8FBF4)
        let accent = DQShare.color(0xF2C879)
        return ZStack {
            LinearGradient(colors: [DQShare.color(0x041F25), DQShare.color(0x06343C)], startPoint: .top, endPoint: .bottom)
            ForEach(4..<29, id: \.self) { i in
                Circle()
                    .stroke(DQShare.color(0x2E8C86).opacity(Double(max(20, 90 - i * 2)) / 255), lineWidth: 2)
                    .frame(width: CGFloat(i) * 76, height: CGFloat(i) * 76)
                    .position(x: 760, y: 1050)
            }
            VStack(alignment: .trailing, spacing: 22) {
                Spacer().frame(height: 160)
                if !ar.isEmpty {
                    Text(ar)
                        .font(DQShare.uthmani(sz.ar))
                        .foregroundStyle(pale)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.68)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                if !ur.isEmpty {
                    Text(ur)
                        .font(DQShare.nastaliq(sz.ur))
                        .foregroundStyle(mint)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(8)
                        .minimumScaleFactor(0.7)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                Spacer()
                if !en.isEmpty {
                    Text(en)
                        .font(DQShare.serif(sz.en))
                        .foregroundStyle(pale.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    if showBrand {
                        Text("be ummati")
                            .font(DQShare.sans(16))
                            .tracking(2)
                            .foregroundStyle(mint.opacity(0.59))
                    }
                    Spacer()
                    if !ref.isEmpty {
                        Text(ref.uppercased())
                            .font(DQShare.sans(20, bold: true))
                            .tracking(2.4)
                            .foregroundStyle(accent)
                    }
                }
                .padding(.bottom, 50)
            }
            .padding(.horizontal, 110)
        }
    }

    // MARK: Riso

    private var riso: some View {
        let paper = DQShare.color(0xFAF7F0)
        let blue = DQShare.color(0x2B3EE0)
        let orange = DQShare.color(0xFF5A36)
        let ink = DQShare.color(0x141414)
        return ZStack {
            paper
            blue.opacity(0.86)
                .frame(height: 560)
                .frame(maxHeight: .infinity, alignment: .top)
            Circle().fill(paper).frame(width: 840, height: 840).position(x: 540, y: 560)
            Circle().fill(orange.opacity(0.78)).frame(width: 660, height: 660).position(x: 834, y: 520)

            VStack(alignment: .trailing, spacing: 20) {
                if !ar.isEmpty {
                    Text(ar)
                        .font(DQShare.uthmani(sz.ar))
                        .foregroundStyle(paper)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(10)
                        .minimumScaleFactor(0.65)
                        .environment(\.layoutDirection, .rightToLeft)
                        .padding(.top, 140)
                }
                Spacer().frame(height: ar.isEmpty ? 560 : 40)
                if !ur.isEmpty {
                    Text(ur)
                        .font(DQShare.nastaliq(sz.ur))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.trailing)
                        .lineSpacing(8)
                        .minimumScaleFactor(0.7)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                Spacer()
                if !en.isEmpty {
                    Text(en)
                        .font(DQShare.serif(sz.en))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(22, bold: true))
                        .tracking(2)
                        .foregroundStyle(blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 50)
                }
            }
            .padding(.horizontal, 100)

            if showBrand {
                Text("BE UMMATI")
                    .font(DQShare.sans(18, bold: true))
                    .tracking(4)
                    .foregroundStyle(orange)
                    .rotationEffect(.degrees(-90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 20)
                    .padding(.bottom, 180)
            }
        }
    }

    // MARK: Girih

    private var girih: some View {
        let midnight = DQShare.color(0x060A18)
        let line = DQShare.color(0x9AA7C7)
        let gold = DQShare.color(0xE0B95F)
        let text = DQShare.color(0xEDF0F8)
        return ZStack {
            midnight
            Circle().fill(DQShare.color(0x131C3A, alpha: 0.39)).frame(width: 1400, height: 1400).position(x: 200, y: 200)
            Circle().fill(DQShare.color(0x131C3A, alpha: 0.35)).frame(width: 1200, height: 1200).position(x: 900, y: 1100)
            Canvas { ctx, _ in
                for i in 0..<8 {
                    for j in 0..<10 {
                        let cx = CGFloat(i) * 220 - 40
                        let cy = CGFloat(j) * 200 - 40
                        var ring = Path()
                        ring.addEllipse(in: CGRect(x: cx - 70, y: cy - 70, width: 140, height: 140))
                        ctx.stroke(ring, with: .color(line.opacity(0.14)), lineWidth: 1.5)
                        var dot = Path()
                        dot.addEllipse(in: CGRect(x: cx + 37, y: cy + 37, width: 6, height: 6))
                        ctx.fill(dot, with: .color(gold.opacity(0.39)))
                    }
                }
            }
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(midnight)
                .frame(width: DQShare.W - 280, height: 700)
                .position(x: 540, y: 630)

            VStack(spacing: 14) {
                OctagonStar()
                    .stroke(gold.opacity(0.85), lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .padding(.top, 88)
                if showBrand {
                    Text("be ummati")
                        .font(DQShare.sans(15))
                        .tracking(4)
                        .foregroundStyle(line.opacity(0.51))
                }
                Spacer()
                centeredStack(arColor: text, urColor: line, enColor: text, sep: gold, showSep: false, maxWidth: 780)
                Spacer()
                if !ref.isEmpty {
                    HStack(spacing: 14) {
                        Rectangle().fill(gold.opacity(0.39)).frame(width: 60, height: 2)
                        Text(ref.uppercased())
                            .font(DQShare.sans(20, bold: true))
                            .tracking(2.8)
                            .foregroundStyle(gold)
                        Rectangle().fill(gold.opacity(0.39)).frame(width: 60, height: 2)
                    }
                    .padding(.bottom, 70)
                }
            }
            .padding(.horizontal, 150)
        }
    }

    // MARK: Keystone (infographic)

    private var keystone: some View {
        let ink = DQShare.color(0x12151A)
        let bone = DQShare.color(0xE8E4DB)
        let brass = DQShare.color(0xC9A24A)
        let panel = DQShare.color(0x1A1F27)
        return ZStack {
            ink
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    DQShare.color(0x0A0C10).frame(height: 160)
                    Rectangle().fill(brass).frame(height: 4)
                    HStack {
                        brandLine(brass)
                        Spacer()
                        if !ref.isEmpty {
                            Text(ref.uppercased())
                                .font(DQShare.sans(18, bold: true))
                                .tracking(1)
                                .foregroundStyle(ink)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(brass, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 72)
                    .padding(.bottom, 28)
                }
                HStack(alignment: .top, spacing: 20) {
                    Rectangle().fill(brass).frame(width: 12)
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(panel)
                        centeredStack(arColor: bone, urColor: bone.opacity(0.82), enColor: brass, sep: brass, showSep: true, maxWidth: 820)
                            .padding(36)
                    }
                }
                .padding(.horizontal, 64)
                .padding(.top, 56)
                .frame(maxHeight: .infinity)
                Text("KEYSTONE")
                    .font(DQShare.sans(14, bold: true))
                    .tracking(4)
                    .foregroundStyle((palette.brand ?? brass).opacity(0.47))
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: Datum (infographic)

    private var datum: some View {
        let deep = DQShare.color(0x0E1A1F)
        let mint = DQShare.color(0x5EE0B5)
        let bone = DQShare.color(0xF2EDE1)
        let mute = DQShare.color(0x9BB0A8)
        return ZStack(alignment: .leading) {
            deep
            HStack(spacing: 0) {
                ZStack {
                    DQShare.color(0x13262C)
                    Rectangle().fill(mint).frame(width: 6).frame(maxWidth: .infinity, alignment: .trailing)
                    Text(palette.brandText.uppercased())
                        .font(DQShare.sans(18, bold: true))
                        .tracking(3)
                        .foregroundStyle(palette.brand ?? mint)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                }
                .frame(width: 120)
                VStack(alignment: .leading, spacing: 28) {
                    if !ref.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ref.uppercased())
                                .font(DQShare.sans(20, bold: true))
                                .tracking(2)
                                .foregroundStyle(mint)
                            Rectangle().fill(mint.opacity(0.63)).frame(width: 140, height: 3)
                        }
                        .padding(.top, 72)
                    }
                    Spacer(minLength: 20)
                    if !ar.isEmpty {
                        datumRow("01", mint) {
                            Text(ar)
                                .font(DQShare.uthmani(sz.ar))
                                .foregroundStyle(palette.arabic ?? bone)
                                .multilineTextAlignment(.trailing)
                                .environment(\.layoutDirection, .rightToLeft)
                                .minimumScaleFactor(0.65)
                        }
                    }
                    if !en.isEmpty {
                        datumRow("02", mute) {
                            Text(en)
                                .font(DQShare.serif(sz.en))
                                .foregroundStyle(palette.english ?? bone)
                                .multilineTextAlignment(.leading)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    if !ur.isEmpty {
                        datumRow("03", mute) {
                            Text(ur)
                                .font(DQShare.nastaliq(sz.ur))
                                .foregroundStyle((palette.urdu ?? mute).opacity(0.92))
                                .multilineTextAlignment(.trailing)
                                .environment(\.layoutDirection, .rightToLeft)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.leading, 48)
                .padding(.trailing, 64)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func datumRow<Content: View>(_ num: String, _ accent: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 8) {
                Circle().fill(accent).frame(width: 10, height: 10)
                Text(num)
                    .font(DQShare.sans(22, bold: true))
                    .tracking(1)
                    .foregroundStyle(accent)
            }
            .frame(width: 48)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Masthead (infographic)

    private var masthead: some View {
        let paper = DQShare.color(0xF7F4EE)
        let ink = DQShare.color(0x1A1A1A)
        let rule = DQShare.color(0x8B1E1E)
        return ZStack {
            paper
            VStack(spacing: 0) {
                brandLine(ink)
                    .padding(.top, 64)
                Rectangle().fill(ink).frame(height: 3).padding(.horizontal, 120).padding(.top, 18)
                Rectangle().fill(rule).frame(height: 2).padding(.horizontal, 120).padding(.top, 6)
                if !ref.isEmpty {
                    Text(ref.uppercased())
                        .font(DQShare.sans(34, bold: true))
                        .tracking(1)
                        .foregroundStyle(ink)
                        .padding(.top, 36)
                    Rectangle().fill(rule).frame(width: 80, height: 4).padding(.top, 14)
                }
                Spacer(minLength: 24)
                centeredStack(arColor: ink, urColor: ink.opacity(0.78), enColor: ink, sep: rule, showSep: true, maxWidth: 820)
                Spacer(minLength: 24)
                Rectangle().fill(ink.opacity(0.63)).frame(height: 2).padding(.horizontal, 120)
                Text("EDITORIAL SERIES")
                    .font(DQShare.sans(14, bold: true))
                    .tracking(4)
                    .foregroundStyle(palette.brand ?? rule)
                    .padding(.top, 22)
                    .padding(.bottom, 56)
            }
            .padding(.horizontal, 48)
        }
    }

    // MARK: Cascade (infographic)

    private var cascade: some View {
        let deep = DQShare.color(0x0B3D2E)
        let mid = DQShare.color(0x14543E)
        let cream = DQShare.color(0xE7D7A8)
        let ink = DQShare.color(0x06231C)
        return ZStack {
            deep
            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(mid)
                    if !ref.isEmpty {
                        Text(ref.uppercased())
                            .font(DQShare.sans(22, bold: true))
                            .tracking(2)
                            .foregroundStyle(cream)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 48)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DQShare.color(0x0F4A38))
                    if !ar.isEmpty {
                        Text(ar)
                            .font(DQShare.uthmani(sz.ar))
                            .foregroundStyle(palette.arabic ?? cream)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.65)
                            .environment(\.layoutDirection, .rightToLeft)
                            .padding(36)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 72)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(cream)
                    if !en.isEmpty {
                        Text(en)
                            .font(DQShare.serif(sz.en))
                            .foregroundStyle(palette.english ?? ink)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)
                            .padding(28)
                    }
                }
                .frame(height: 250)
                .padding(.horizontal, 96)

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DQShare.color(0x0A3328))
                    if !ur.isEmpty {
                        Text(ur)
                            .font(DQShare.nastaliq(sz.ur))
                            .foregroundStyle((palette.urdu ?? cream).opacity(0.9))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .environment(\.layoutDirection, .rightToLeft)
                            .padding(24)
                    }
                }
                .frame(height: 170)
                .padding(.horizontal, 120)

                brandLine(cream.opacity(0.51))
                    .padding(.bottom, 28)
            }
            .padding(.top, 56)
        }
    }

    // MARK: Signal (infographic)

    private var signal: some View {
        let navy = DQShare.color(0x0A1628)
        let sand = DQShare.color(0xE8DCC8)
        let gold = DQShare.color(0xD4A017)
        return ZStack(alignment: .leading) {
            navy
            Rectangle().fill(gold).frame(width: 28)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    if !ref.isEmpty {
                        ZStack {
                            Circle().fill(gold).frame(width: 156, height: 156)
                            Text(ref.uppercased())
                                .font(DQShare.sans(14, bold: true))
                                .tracking(0.5)
                                .foregroundStyle(navy)
                                .multilineTextAlignment(.center)
                                .frame(width: 120)
                        }
                        .padding(.leading, 64)
                        .padding(.top, 64)
                    }
                    Spacer()
                    brandLine(sand)
                        .padding(.trailing, 72)
                        .padding(.top, 72)
                }
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(DQShare.color(0x122033))
                    Rectangle().fill(gold).frame(width: 12)
                    centeredStack(arColor: sand, urColor: sand.opacity(0.82), enColor: gold, sep: gold, showSep: true, maxWidth: 820)
                        .padding(.leading, 36)
                        .padding(32)
                }
                .padding(.horizontal, 56)
                .padding(.top, 40)
                .frame(maxHeight: .infinity)
                Text("SIGNAL")
                    .font(DQShare.sans(14, bold: true))
                    .tracking(4)
                    .foregroundStyle((palette.brand ?? gold).opacity(0.55))
                    .padding(.leading, 88)
                    .padding(.bottom, 48)
            }
        }
    }

    // MARK: Shared text stack

    @ViewBuilder
    private func centeredStack(
        arColor: Color, urColor: Color, enColor: Color,
        sep: Color, showSep: Bool, maxWidth: CGFloat,
        arBoost: CGFloat = 0
    ) -> some View {
        let a = palette.arabic ?? arColor
        let u = palette.urdu ?? urColor
        let e = palette.english ?? enColor
        let s = palette.brand ?? sep
        VStack(spacing: 22) {
            if !ar.isEmpty {
                Text(ar)
                    .font(DQShare.uthmani(sz.ar + arBoost))
                    .foregroundStyle(a)
                    .multilineTextAlignment(.center)
                    .lineSpacing(10)
                    .minimumScaleFactor(0.65)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            if showSep && !ar.isEmpty && (!ur.isEmpty || !en.isEmpty) {
                HStack(spacing: 14) {
                    Rectangle().fill(s.opacity(0.47)).frame(width: 66, height: 2)
                    Circle().fill(s.opacity(0.47)).frame(width: 10, height: 10)
                    Rectangle().fill(s.opacity(0.47)).frame(width: 66, height: 2)
                }
            }
            if !ur.isEmpty {
                Text(ur)
                    .font(DQShare.nastaliq(sz.ur))
                    .foregroundStyle(u.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .minimumScaleFactor(0.7)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            if !en.isEmpty {
                Text(en)
                    .font(DQShare.serif(sz.en))
                    .foregroundStyle(e)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: maxWidth * 0.92)
            }
        }
        .frame(maxWidth: maxWidth)
    }

    private func brandLine(_ color: Color) -> some View {
        Text(palette.brandText.uppercased())
            .font(DQShare.sans(16, bold: true))
            .tracking(4)
            .foregroundStyle(palette.brand ?? color)
    }
}

// MARK: - Shapes

private struct MihrabArch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: 70, y: h + 20))
        p.addLine(to: CGPoint(x: 70, y: 720))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: 110), control: CGPoint(x: 70, y: 190))
        p.addQuadCurve(to: CGPoint(x: w - 70, y: 720), control: CGPoint(x: w - 70, y: 190))
        p.addLine(to: CGPoint(x: w - 70, y: h + 20))
        p.closeSubpath()
        return p
    }
}

private struct FajrDune: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: -40, y: h))
        p.addLine(to: CGPoint(x: -40, y: 1180))
        p.addCurve(to: CGPoint(x: 700, y: 1080), control1: CGPoint(x: 200, y: 1040), control2: CGPoint(x: 500, y: 1120))
        p.addCurve(to: CGPoint(x: w + 40, y: 1160), control1: CGPoint(x: 900, y: 1040), control2: CGPoint(x: 1100, y: 1140))
        p.addLine(to: CGPoint(x: w + 40, y: h))
        p.closeSubpath()
        return p
    }
}

private struct OctagonStar: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        for i in 0..<8 {
            let a = Double(i) * .pi / 4 - .pi / 2
            let pt = CGPoint(x: cx + r * CGFloat(cos(a)), y: cy + r * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

private struct KuficLattice: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var rng = SeededGenerator(seed: 42)
        for row in 0..<14 {
            for col in 0..<11 {
                if Float.random(in: 0...1, using: &rng) > 0.35 { continue }
                let x = CGFloat(col) * 96
                let y = CGFloat(row) * 96
                switch Int.random(in: 0..<3, using: &rng) {
                case 0:
                    p.move(to: CGPoint(x: x, y: y + 48)); p.addLine(to: CGPoint(x: x + 72, y: y + 48))
                    p.move(to: CGPoint(x: x + 72, y: y + 48)); p.addLine(to: CGPoint(x: x + 72, y: y + 96))
                case 1:
                    p.move(to: CGPoint(x: x + 24, y: y)); p.addLine(to: CGPoint(x: x + 24, y: y + 72))
                    p.move(to: CGPoint(x: x + 24, y: y + 72)); p.addLine(to: CGPoint(x: x + 96, y: y + 72))
                default:
                    p.move(to: CGPoint(x: x, y: y + 24)); p.addLine(to: CGPoint(x: x + 48, y: y + 24))
                    p.move(to: CGPoint(x: x + 48, y: y + 24)); p.addLine(to: CGPoint(x: x + 48, y: y + 96))
                }
            }
        }
        return p
    }
}

/// Deterministic RNG so decor looks stable across renders.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
