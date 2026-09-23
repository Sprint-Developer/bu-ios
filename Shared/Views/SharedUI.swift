import SwiftUI
import UIKit

struct ReminderBanner: View {
    @ObservedObject var store: ReminderStore
    @ObservedObject var notes: NotesStore
    @EnvironmentObject var reading: ReadingSettings
    var onOpen: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item = store.current {
                HStack {
                    Text(item.kind.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                    if !item.theme.isEmpty {
                        Text("· \(item.theme)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(item.ref)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                if !item.title.isEmpty {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                TripleText(arabic: item.arabic, english: item.english, urdu: item.urdu)
                reminderActions(item)
            } else if store.loading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { onOpen?() }
    }

    @ViewBuilder
    private func reminderActions(_ item: ReminderItem) -> some View {
        HStack(spacing: 12) {
            BeUmmatiShareButton(
                title: item.title.isEmpty ? nil : item.title,
                kind: item.kind,
                ref: item.ref,
                arabic: item.arabic,
                english: item.english,
                urdu: item.urdu
            )
            Button {
                notes.add(
                    title: item.title.isEmpty ? "\(item.kind) \(item.ref)" : item.title,
                    body: ShareText.compose(
                        title: item.title,
                        kind: item.kind,
                        ref: item.ref,
                        arabic: item.arabic,
                        english: item.english,
                        urdu: item.urdu,
                        reading: reading
                    ),
                    ref: item.ref
                )
            } label: {
                Label("Note", systemImage: "square.and.pencil")
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                store.refresh()
            } label: {
                Label("Next", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color(red: 0.2, green: 0.55, blue: 0.42))
    }
}

struct TripleText: View {
    @EnvironmentObject var reading: ReadingSettings
    let arabic: String
    let english: String
    let urdu: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if reading.showArabic, !arabic.isEmpty {
                langBlock(label: "العربية", subtitle: "Arabic", rtl: true) {
                    Text(arabic)
                        .font(reading.arabicFont.font(size: reading.arabicSize))
                        .foregroundStyle(reading.arabicColor)
                        .lineSpacing(reading.arabicLineSpacing)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .beUmmatiSelectableText()
                }
            }
            if reading.showEnglish, !english.isEmpty {
                langBlock(label: "English", subtitle: nil, rtl: false) {
                    MixedScriptProseText(
                        text: english,
                        englishSize: reading.englishSize + 1,
                        arabicSize: reading.englishSize + 2,
                        arabicPostScriptName: reading.arabicFont.postScriptName,
                        englishColor: UIColor(reading.englishColor),
                        arabicColor: UIColor(reading.englishColor)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if reading.showUrdu, !urdu.isEmpty {
                langBlock(label: "اردو", subtitle: "Urdu", rtl: true) {
                    ShapedUrduBlock(
                        text: urdu,
                        fontSize: reading.urduSize + 1,
                        postScriptName: reading.urduFont.postScriptName,
                        textColor: UIColor(reading.urduColor)
                    )
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func langBlock<Content: View>(label: String, subtitle: String?, rtl: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: rtl ? .trailing : .leading, spacing: 6) {
            if reading.showLangLabels {
                HStack(spacing: 6) {
                    if rtl { Spacer(minLength: 0) }
                    if let subtitle, rtl {
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.2, green: 0.55, blue: 0.42))
                    if let subtitle, !rtl {
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    if !rtl { Spacer(minLength: 0) }
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
    }
}
