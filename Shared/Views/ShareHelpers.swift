import SwiftUI

enum ShareText {
    /// Always includes reference. Languages follow share* flags.
    @MainActor
    static func compose(
        title: String? = nil,
        kind: String? = nil,
        ref: String,
        arabic: String,
        english: String,
        urdu: String,
        reading: ReadingSettings
    ) -> String {
        compose(
            title: title,
            kind: kind,
            ref: ref,
            arabic: arabic,
            english: english,
            urdu: urdu,
            shareArabic: reading.shareArabic,
            shareEnglish: reading.shareEnglish,
            shareUrdu: reading.shareUrdu
        )
    }

    static func compose(
        title: String? = nil,
        kind: String? = nil,
        ref: String,
        arabic: String,
        english: String,
        urdu: String,
        shareArabic: Bool,
        shareEnglish: Bool,
        shareUrdu: Bool
    ) -> String {
        var parts: [String] = []
        if let title, !title.isEmpty { parts.append(title) }
        if !ref.isEmpty {
            if let kind, !kind.isEmpty {
                parts.append("\(kind) — \(ref)")
            } else {
                parts.append(ref)
            }
        } else if let kind, !kind.isEmpty {
            parts.append(kind)
        }
        parts.append("")

        let any = shareArabic || shareEnglish || shareUrdu
        let useAr = any ? shareArabic : true
        let useEn = any ? shareEnglish : true
        let useUr = any ? shareUrdu : true

        if useAr, !arabic.isEmpty {
            parts.append(arabic)
            parts.append("")
        }
        if useEn, !english.isEmpty {
            parts.append(english)
            parts.append("")
        }
        if useUr, !urdu.isEmpty {
            parts.append(urdu)
            parts.append("")
        }
        parts.append("— Be Ummati")
        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Opens share studio with language checkboxes (text mode).
struct BeUmmatiShareButton: View {
    @EnvironmentObject var reading: ReadingSettings
    var title: String? = nil
    var kind: String? = nil
    let ref: String
    let arabic: String
    let english: String
    let urdu: String
    var label: String = "Share"

    @State private var showStudio = false

    var body: some View {
        Button {
            showStudio = true
        } label: {
            Label(label, systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showStudio) {
            ShareCardStudioView(
                title: title,
                kind: kind,
                ref: ref,
                arabic: arabic,
                english: english,
                urdu: urdu,
                mode: .text
            )
            .environmentObject(reading)
        }
    }
}
