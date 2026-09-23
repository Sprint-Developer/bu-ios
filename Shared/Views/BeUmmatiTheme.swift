import SwiftUI
import UIKit

enum BeUmmatiTheme {
    private static var p: ThemePalette { ThemeStore.shared.palette }

    static var parchment: Color { p.parchment }
    static var parchmentDeep: Color { p.parchmentDeep }
    static var teal: Color { p.teal }
    static var tealSoft: Color { p.tealSoft }
    static var tealMuted: Color { p.tealMuted }
    static var brass: Color { p.brass }
    static var brassSoft: Color { p.brassSoft }
    static var card: Color { p.card }
    static var ink: Color { p.ink }
    static var inkSecondary: Color { p.inkSecondary }

    static func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        for name in ["Fraunces-Regular", "Fraunces", "FrauncesRoman-Regular"] {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size, weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

struct BeUmmatiCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BeUmmatiTheme.card)
                    .shadow(color: .black.opacity(ThemeStore.shared.kind.isDark ? 0.35 : 0.06), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(BeUmmatiTheme.brass.opacity(ThemeStore.shared.kind.isDark ? 0.22 : 0.18), lineWidth: 1)
            )
    }
}

extension View {
    func beUmmatiCard() -> some View {
        modifier(BeUmmatiCardModifier())
    }

    func beUmmatiScreenBackground() -> some View {
        self.background(BeUmmatiTheme.parchment.ignoresSafeArea())
    }
}

struct BeUmmatiChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BeUmmatiTheme.ui(13, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? BeUmmatiTheme.teal : BeUmmatiTheme.card.opacity(0.9), in: Capsule())
                .foregroundStyle(selected ? Color.white : BeUmmatiTheme.ink)
                .overlay(Capsule().stroke(BeUmmatiTheme.teal.opacity(selected ? 0 : 0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ThemeSettingsView: View {
    @ObservedObject var theme: ThemeStore

    var body: some View {
        List {
            Section("Appearance") {
                Picker("System look", selection: $theme.appearance) {
                    ForEach(AppAppearance.allCases) { a in
                        Text(a.title).tag(a)
                    }
                }
                .pickerStyle(.segmented)
                Text("Controls iOS light/dark chrome (lists, sheets). App colors still follow the theme below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("App theme") {
                ForEach(AppThemeKind.allCases) { kind in
                    Button {
                        theme.kind = kind
                    } label: {
                        HStack(spacing: 14) {
                            ThemeSwatch(kind: kind)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(kind.title)
                                    .font(BeUmmatiTheme.heading(17))
                                    .foregroundStyle(BeUmmatiTheme.ink)
                                Text(kind.subtitle)
                                    .font(BeUmmatiTheme.ui(12))
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            }
                            Spacer()
                            if theme.kind == kind {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(BeUmmatiTheme.teal)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
        .navigationTitle("Theme")
    }
}

private struct ThemeSwatch: View {
    let kind: AppThemeKind

    var body: some View {
        let p = kind.palette
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(p.parchment)
            HStack(spacing: 0) {
                p.teal
                p.brass
                p.ink.opacity(0.35)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(6)
        }
        .frame(width: 52, height: 40)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(p.ink.opacity(0.12), lineWidth: 1)
        )
    }
}
