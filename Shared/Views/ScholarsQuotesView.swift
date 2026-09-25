import SwiftUI

/// Top-level Scholars library: names → quotes → share.
struct ScholarsLibraryView: View {
    @State private var query = ""

    private var scholars: [ScholarProfile] {
        let list = ScholarQuotes.catalog
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return list }
        return list.filter {
            $0.name.lowercased().contains(q)
                || $0.blurb.lowercased().contains(q)
                || $0.era.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Curated library of \(ScholarQuotes.all.count) verified sayings with book citations. Their works contain far more — we only ship lines we can source, and grow the library carefully.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Scholars") {
                    ForEach(scholars) { s in
                        NavigationLink {
                            ScholarDetailView(scholar: s)
                        } label: {
                            HStack(spacing: 14) {
                                Text(initials(s.name))
                                    .font(BeUmmatiTheme.ui(14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(BeUmmatiTheme.teal, in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(s.name)
                                        .font(BeUmmatiTheme.heading(17))
                                        .foregroundStyle(BeUmmatiTheme.ink)
                                    Text("\(s.era) · \(s.blurb)")
                                        .font(BeUmmatiTheme.ui(12))
                                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 8)
                                Text("\(ScholarQuotes.count(for: s.id))")
                                    .font(BeUmmatiTheme.ui(13, weight: .bold))
                                    .foregroundStyle(BeUmmatiTheme.brass)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BeUmmatiTheme.parchment)
            .navigationTitle("Scholars")
            .searchable(text: $query, prompt: "Search scholars")
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name
            .replacingOccurrences(of: "Imam ", with: "")
            .replacingOccurrences(of: "al-", with: "")
            .split(separator: " ")
        if let first = parts.first {
            return String(first.prefix(1)).uppercased()
        }
        return "?"
    }
}

struct ScholarDetailView: View {
    let scholar: ScholarProfile
    @EnvironmentObject var reading: ReadingSettings
    @EnvironmentObject var bookmarks: BookmarkStore
    @StateObject private var notes = NotesStore()
    @State private var themeFilter: String?

    private var quotes: [ScholarQuote] {
        let list = ScholarQuotes.quotes(for: scholar.id)
        guard let themeFilter else { return list }
        return list.filter { $0.theme == themeFilter }
    }

    private var themes: [String] {
        Array(Set(ScholarQuotes.quotes(for: scholar.id).map(\.theme))).sorted()
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(scholar.era)
                        .font(BeUmmatiTheme.ui(13, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                    Text(scholar.blurb)
                        .font(BeUmmatiTheme.ui(14))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                }
                .padding(.vertical, 4)
            }
            if !themes.isEmpty {
                Section("Theme") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            BeUmmatiChip(title: "All", selected: themeFilter == nil) { themeFilter = nil }
                            ForEach(themes, id: \.self) { t in
                                BeUmmatiChip(title: t, selected: themeFilter == t) {
                                    themeFilter = themeFilter == t ? nil : t
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            Section("\(quotes.count) sayings") {
                if quotes.isEmpty {
                    Text("No cited sayings yet for this scholar.")
                        .foregroundStyle(.secondary)
                }
                ForEach(quotes) { q in
                    ScholarQuoteCard(quote: q, notes: notes)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
        .navigationTitle(scholar.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ScholarQuoteCard: View {
    let quote: ScholarQuote
    @ObservedObject var notes: NotesStore
    @EnvironmentObject var reading: ReadingSettings
    @EnvironmentObject var bookmarks: BookmarkStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(quote.title)
                .font(BeUmmatiTheme.heading(17))
                .foregroundStyle(BeUmmatiTheme.ink)
            TripleText(arabic: quote.arabic, english: quote.english, urdu: quote.urdu)
            Text(quote.reference)
                .font(BeUmmatiTheme.ui(12, weight: .medium))
                .foregroundStyle(BeUmmatiTheme.inkSecondary)
            HStack(spacing: 10) {
                BeUmmatiShareButton(
                    title: quote.title,
                    kind: "Scholar",
                    ref: quote.displayRef,
                    arabic: quote.arabic,
                    english: quote.english,
                    urdu: quote.urdu
                )
                GiftReminderButton(
                    title: quote.title,
                    kind: "Scholar",
                    ref: quote.displayRef,
                    arabic: quote.arabic,
                    english: quote.english,
                    urdu: quote.urdu
                )
            }
            .font(BeUmmatiTheme.ui(13, weight: .semibold))
            .foregroundStyle(BeUmmatiTheme.teal)
            HStack {
                Button {
                    notes.add(
                        title: "\(quote.author) — \(quote.title)",
                        body: ShareText.compose(
                            title: quote.title,
                            kind: "Scholar",
                            ref: quote.displayRef,
                            arabic: quote.arabic,
                            english: quote.english,
                            urdu: quote.urdu,
                            reading: reading
                        ),
                        ref: quote.displayRef,
                        tags: ["scholars", quote.author],
                        linkKind: "Scholar"
                    )
                } label: {
                    Label("Note", systemImage: "square.and.pencil")
                }
                .buttonStyle(.plain)
                Button {
                    bookmarks.toggle(
                        kind: "Scholar",
                        ref: quote.displayRef,
                        title: "\(quote.author) — \(quote.title)",
                        arabic: quote.arabic,
                        english: quote.english,
                        urdu: quote.urdu
                    )
                } label: {
                    Label(
                        bookmarks.isBookmarked(kind: "Scholar", ref: quote.displayRef) ? "Saved" : "Save",
                        systemImage: bookmarks.isBookmarked(kind: "Scholar", ref: quote.displayRef) ? "bookmark.fill" : "bookmark"
                    )
                }
                .buttonStyle(.plain)
            }
            .font(BeUmmatiTheme.ui(13, weight: .semibold))
            .foregroundStyle(BeUmmatiTheme.teal)
        }
        .padding(.vertical, 6)
    }
}

/// Kept for Settings deep-link compatibility.
typealias ScholarsQuotesView = ScholarsLibraryView
