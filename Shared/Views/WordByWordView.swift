import SwiftUI

struct WordByWordView: View {
    let ayahKey: String
    @EnvironmentObject var reading: ReadingSettings
    @State private var words: [QuranWord] = []
    @State private var selected: QuranWord?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ayahKey)
                    .font(BeUmmatiTheme.ui(13, weight: .bold))
                    .foregroundStyle(BeUmmatiTheme.brass)

                if loading {
                    ProgressView("Loading words…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let error {
                    Text(error)
                        .font(BeUmmatiTheme.ui(14))
                        .foregroundStyle(.secondary)
                } else {
                    FlowWords(words: words, selected: $selected)

                    if let selected {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selected.text)
                                .font(reading.arabicFont.font(size: reading.arabicSize + 4))
                                .foregroundStyle(reading.arabicColor)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .environment(\.layoutDirection, .leftToRight)
                            if !selected.transliteration.isEmpty {
                                Text(selected.transliteration)
                                    .font(BeUmmatiTheme.ui(14, weight: .medium))
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            }
                            if !selected.translation.isEmpty {
                                Text(selected.translation)
                                    .font(BeUmmatiTheme.ui(16))
                                    .foregroundStyle(BeUmmatiTheme.ink)
                            }
                        }
                        .padding(14)
                        .beUmmatiCard()
                    } else {
                        Text("Tap a word for its meaning")
                            .font(BeUmmatiTheme.ui(13))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    }
                }
            }
            .padding(20)
        }
        .beUmmatiScreenBackground()
        .navigationTitle("Word by word")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            words = try await QuranAPI.shared.words(key: ayahKey)
            error = nil
            selected = words.first
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct FlowWords: View {
    let words: [QuranWord]
    @Binding var selected: QuranWord?
    @EnvironmentObject var reading: ReadingSettings

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            ForEach(Array(chunks(of: words, size: 5).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row.reversed()) { w in
                        Button {
                            selected = w
                        } label: {
                            Text(w.text)
                                .font(reading.arabicFont.font(size: reading.arabicSize))
                                .foregroundStyle(selected?.position == w.position ? BeUmmatiTheme.teal : reading.arabicColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(
                                    selected?.position == w.position ? BeUmmatiTheme.tealSoft : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func chunks(of list: [QuranWord], size: Int) -> [[QuranWord]] {
        stride(from: 0, to: list.count, by: size).map {
            Array(list[$0..<min($0 + size, list.count)])
        }
    }
}

struct RelatedAyahDestination: View {
    let key: String
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var plan: DailyPlanStore
    @State private var chapter: QuranChapter?
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView()
            } else if let chapter {
                SurahDetailView(
                    chapter: chapter,
                    notes: notes,
                    bookmarks: bookmarks,
                    plan: plan,
                    initialAyahKey: key
                )
            } else {
                ContentUnavailableView("Couldn’t open", systemImage: "book.closed")
            }
        }
        .task {
            loading = true
            defer { loading = false }
            let parts = key.split(separator: ":")
            guard parts.count == 2, let surah = Int(parts[0]) else { return }
            if let chapters = try? await QuranAPI.shared.chapters(),
               let match = chapters.first(where: { $0.id == surah }) {
                chapter = match
            } else {
                chapter = QuranChapter(
                    id: surah,
                    nameArabic: "",
                    nameSimple: "Surah \(surah)",
                    versesCount: 286,
                    revelationPlace: ""
                )
            }
        }
    }
}
