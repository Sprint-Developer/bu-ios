import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Brand tokens

private enum BeUmmatiShare {
    static let brandRed = Color(red: 0.90, green: 0.0, blue: 0.05)
}

/// Formats a share reference for premium cards (matches Android DailyQuranLab).
enum ShareCardReference {
    static func display(kind: String?, title: String?, ref: String) -> String {
        let ayahKey = firstMatch(#"(\d+)\s*:\s*(\d+)"#, in: ref)
            ?? firstMatch(#"(\d+)\s*:\s*(\d+)"#, in: title ?? "")
            ?? ""
        let k = (kind ?? "").lowercased()
        if k.contains("qur") || ayahKey.contains(":") {
            var surah = (title ?? "")
                .replacingOccurrences(of: ayahKey, with: "")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if surah.isEmpty { surah = "QURAN" }
            return "AL QURAN SURAH \(surah.uppercased()) \(ayahKey)".trimmingCharacters(in: .whitespaces)
        }
        if !ref.isEmpty { return ref.uppercased() }
        return (title ?? "").uppercased()
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = re.firstMatch(in: text, range: range),
              let r = Range(m.range, in: text) else { return nil }
        return String(text[r])
    }
}

// MARK: - Card wrapper

struct ShareCardView: View {
    let style: ShareCardStyle
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
    var palette: SharePalette = .design

    var body: some View {
        DailyQuranShareCard(
            style: style,
            arabic: arabic,
            english: english,
            urdu: urdu,
            reference: ShareCardReference.display(kind: kind, title: title, ref: ref),
            showArabic: showArabic,
            showEnglish: showEnglish,
            showUrdu: showUrdu,
            showBrand: showBrand,
            showReference: showReference,
            palette: palette
        )
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

    var body: some View {
        BeUmmatiShareButton(
            title: title,
            kind: kind,
            ref: ref,
            arabic: arabic,
            english: english,
            urdu: urdu,
            label: "Share",
            initialMode: .image
        )
    }
}

enum ShareStudioMode: String, CaseIterable, Identifiable {
    case image
    case text

    var id: String { rawValue }

    var label: String {
        switch self {
        case .image: return "Image card"
        case .text: return "Plain text"
        }
    }
}

/// Languages + edit text + designs — shared by Quran, Hadith, Duas, reminders, etc.
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

    @State private var activeMode: ShareStudioMode = .image
    @State private var style: ShareCardStyle = .mihrab
    @State private var palette: SharePalette = .design
    @State private var palettePresetLabel: String = "Design"

    @State private var includeArabic = true
    @State private var includeEnglish = true
    @State private var includeUrdu = true

    @State private var includeReference = true
    @State private var includeBrand = true
    @State private var includeTitle = true

    @State private var cropArabic = ""
    @State private var cropEnglish = ""
    @State private var cropUrdu = ""

    @State private var payload: ShareablePNG?
    @State private var preview: UIImage?
    @State private var preparing = false
    @State private var renderToken = 0

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
                    Picker("Share as", selection: $activeMode) {
                        ForEach(ShareStudioMode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

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

                    sectionHeader("Edit text")
                    Text("Shorten or rewrite any language before sharing. Preview updates live.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        if hasArabic {
                            cropEditor(label: "Arabic", text: $cropArabic, full: arabic, reset: {
                                cropArabic = arabic
                            })
                            .opacity(includeArabic ? 1 : 0.45)
                            .disabled(!includeArabic)
                        }
                        if hasEnglish {
                            cropEditor(label: "English", text: $cropEnglish, full: english, reset: {
                                cropEnglish = english
                            })
                            .opacity(includeEnglish ? 1 : 0.45)
                            .disabled(!includeEnglish)
                        }
                        if hasUrdu {
                            cropEditor(label: "Urdu", text: $cropUrdu, full: urdu, reset: {
                                cropUrdu = urdu
                            })
                            .opacity(includeUrdu ? 1 : 0.45)
                            .disabled(!includeUrdu)
                        }

                        Button("Reset all to original") {
                            cropArabic = arabic
                            cropEnglish = english
                            cropUrdu = urdu
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal)

                    sectionHeader("On the card")
                    VStack(spacing: 0) {
                        toggleRow("Reference", isOn: $includeReference)
                        Divider().padding(.leading, 16)
                        toggleRow("Title", isOn: $includeTitle)
                        if activeMode == .image {
                            Divider().padding(.leading, 16)
                            toggleRow("Be Ummati mark", isOn: $includeBrand)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)

                    if activeMode == .image {
                        sectionHeader("Design")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ShareCardStyle.allCases) { s in
                                    styleChip(s)
                                }
                            }
                            .padding(.horizontal)
                        }

                        Text(style.blurb)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        sectionHeader("Colours")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(SharePalette.presets, id: \.label) { item in
                                    palettePresetChip(item.label, item.palette)
                                }
                            }
                            .padding(.horizontal)
                        }
                        Text(palette.hasBackgroundTint
                             ? "Background tint · design template kept"
                             : "Design art · override text / logo colours below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 12) {
                            colourRoleRow("Background", color: $palette.background, allowClear: true)
                            colourRoleRow("Arabic", color: Binding(
                                get: { palette.arabic },
                                set: { palette.arabic = $0 }
                            ), allowClear: true)
                            colourRoleRow("English", color: Binding(
                                get: { palette.english },
                                set: { palette.english = $0 }
                            ), allowClear: true)
                            colourRoleRow("Urdu", color: Binding(
                                get: { palette.urdu },
                                set: { palette.urdu = $0 }
                            ), allowClear: true)
                            colourRoleRow("Logo", color: Binding(
                                get: { palette.brand },
                                set: { palette.brand = $0 }
                            ), allowClear: true)

                            HStack {
                                Text("Logo text")
                                    .font(.subheadline.weight(.semibold))
                                TextField("BE UMMATI", text: $palette.brandText)
                                    .textInputAutocapitalization(.characters)
                                    .font(.subheadline.weight(.bold))
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.horizontal, 4)

                            Button("Reset colours to design") {
                                palette = .design
                                palettePresetLabel = "Design"
                                scheduleRender(immediate: true)
                            }
                            .font(.caption.weight(.semibold))
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal)

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
                        sectionHeader("Preview")
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

                    Button("Save language + design + colour as default") {
                        reading.shareArabic = includeArabic
                        reading.shareEnglish = includeEnglish
                        reading.shareUrdu = includeUrdu
                        UserDefaults.standard.set(style.rawValue, forKey: "beummati.shareStyle")
                        UserDefaults.standard.set(palettePresetLabel, forKey: "beummati.sharePalettePreset")
                        UserDefaults.standard.set(palette.brandText, forKey: "beummati.shareBrandText")
                        Self.storeOptionalColor(palette.background, key: "beummati.sharePal.bg")
                        Self.storeOptionalColor(palette.arabic, key: "beummati.sharePal.ar")
                        Self.storeOptionalColor(palette.english, key: "beummati.sharePal.en")
                        Self.storeOptionalColor(palette.urdu, key: "beummati.sharePal.ur")
                        Self.storeOptionalColor(palette.brand, key: "beummati.sharePal.brand")
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                activeMode = mode
                if let saved = UserDefaults.standard.string(forKey: "beummati.shareStyle"),
                   let s = ShareCardStyle(rawValue: saved) {
                    style = s
                } else {
                    style = ShareCardStyle.preferred(for: kind)
                }
                if let preset = UserDefaults.standard.string(forKey: "beummati.sharePalettePreset"),
                   let match = SharePalette.presets.first(where: { $0.label == preset }) {
                    palette = match.palette
                    palettePresetLabel = match.label
                }
                if let brand = UserDefaults.standard.string(forKey: "beummati.shareBrandText"), !brand.isEmpty {
                    palette.brandText = brand
                }
                if let bg = Self.loadOptionalColor(key: "beummati.sharePal.bg") { palette.background = bg }
                if let ar = Self.loadOptionalColor(key: "beummati.sharePal.ar") { palette.arabic = ar }
                if let en = Self.loadOptionalColor(key: "beummati.sharePal.en") { palette.english = en }
                if let ur = Self.loadOptionalColor(key: "beummati.sharePal.ur") { palette.urdu = ur }
                if let br = Self.loadOptionalColor(key: "beummati.sharePal.brand") { palette.brand = br }
                includeArabic = reading.shareArabic && hasArabic
                includeEnglish = reading.shareEnglish && hasEnglish
                includeUrdu = reading.shareUrdu && hasUrdu
                if !includeArabic && !includeEnglish && !includeUrdu {
                    includeArabic = hasArabic
                    includeEnglish = hasEnglish
                    includeUrdu = hasUrdu
                }
                cropArabic = arabic
                cropEnglish = english
                cropUrdu = urdu
                render()
            }
            .onChange(of: activeMode) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: style) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: palette) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: includeArabic) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: includeEnglish) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: includeUrdu) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: includeReference) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: includeBrand) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: includeTitle) { _, _ in scheduleRender(immediate: true) }
            .onChange(of: cropArabic) { _, _ in scheduleRender() }
            .onChange(of: cropEnglish) { _, _ in scheduleRender() }
            .onChange(of: cropUrdu) { _, _ in scheduleRender() }
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

    private func styleChip(_ s: ShareCardStyle) -> some View {
        let selected = style == s
        return Button {
            style = s
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: s.swatch,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(selected ? BeUmmatiShare.brandRed : Color.clear, lineWidth: 2.5)
                        .frame(width: 62, height: 76)
                )
                Text(s.label)
                    .font(.caption2.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(s.label) design")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func palettePresetChip(_ label: String, _ p: SharePalette) -> some View {
        let selected = palettePresetLabel == label
        return Button {
            palettePresetLabel = label
            var next = p
            next.brandText = palette.brandText
            palette = next
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if let bg = p.background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(bg)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(colors: style.swatch, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                }
                .frame(width: 52, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? BeUmmatiShare.brandRed : Color.primary.opacity(0.12), lineWidth: selected ? 2.5 : 1)
                )
                Text(label)
                    .font(.caption2.weight(selected ? .bold : .medium))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
    }

    private func colourRoleRow(_ title: String, color: Binding<Color?>, allowClear: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if allowClear, color.wrappedValue != nil {
                    Button("Design") { color.wrappedValue = nil }
                        .font(.caption.weight(.semibold))
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(SharePalette.swatches.enumerated()), id: \.offset) { _, swatch in
                        let selected = color.wrappedValue.map { colorsEqual($0, swatch) } ?? false
                        Button {
                            color.wrappedValue = swatch
                            if title == "Background" { palettePresetLabel = "Custom" }
                        } label: {
                            Circle()
                                .fill(swatch)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(selected ? BeUmmatiShare.brandRed : Color.primary.opacity(0.15), lineWidth: selected ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func colorsEqual(_ a: Color, _ b: Color) -> Bool {
        let ua = UIColor(a), ub = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ua.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        ub.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return abs(ar - br) < 0.02 && abs(ag - bg) < 0.02 && abs(ab - bb) < 0.02
    }

    private static func storeOptionalColor(_ color: Color?, key: String) {
        guard let color else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        UserDefaults.standard.set([Double(r), Double(g), Double(b), Double(a)], forKey: key)
    }

    private static func loadOptionalColor(key: String) -> Color? {
        guard let arr = UserDefaults.standard.array(forKey: key) as? [Double], arr.count == 4 else { return nil }
        return Color(.sRGB, red: arr[0], green: arr[1], blue: arr[2], opacity: arr[3])
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
    private func scheduleRender(immediate: Bool = false) {
        renderToken &+= 1
        let token = renderToken
        if immediate {
            render()
            return
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard token == renderToken else { return }
            render()
        }
    }

    @MainActor
    private func render() {
        guard activeMode == .image else { return }
        preparing = true
        payload = nil
        preview = nil

        let card = ShareCardView(
            style: style,
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
            showSlogan: false,
            showReference: includeReference,
            palette: palette
        )
        // Logical 1080×1350 → export at native IG 4:5 resolution
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
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
