import SwiftUI

/// Opens the full ayah or hadith for a Today reminder.
struct ReminderDestinationView: View {
    let item: ReminderItem
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var plan: DailyPlanStore

    @State private var chapter: QuranChapter?
    @State private var hadithBook: HadithBookInfo?
    @State private var hadithChapter: HadithChapter?
    @State private var startNumber: Int = 1
    @State private var error: String?
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView("Opening…")
            } else if let error {
                ContentUnavailableView("Couldn’t open", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if let chapter {
                SurahDetailView(
                    chapter: chapter,
                    notes: notes,
                    bookmarks: bookmarks,
                    plan: plan,
                    initialAyahKey: item.quranKey
                )
            } else if let book = hadithBook, let ch = hadithChapter {
                HadithReaderView(
                    book: book,
                    chapter: ch,
                    startNumber: startNumber,
                    notes: notes,
                    bookmarks: bookmarks
                )
            } else {
                ContentUnavailableView("Unavailable", systemImage: "questionmark.circle")
            }
        }
        .task { await resolve() }
    }

    private func resolve() async {
        loading = true
        defer { loading = false }

        if let key = item.quranKey {
            let parts = key.split(separator: ":")
            guard parts.count == 2, let surah = Int(parts[0]), let _ = Int(parts[1]) else {
                error = "Invalid ayah reference."
                return
            }
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
            return
        }

        if let slug = item.hadithBook, let number = item.hadithNumber {
            guard let book = HadithAPI.catalog.first(where: { $0.slug == slug }) else {
                error = "Hadith book not found."
                return
            }
            hadithBook = book
            startNumber = number
            if let ch = book.chapters.first(where: { number >= $0.first && number <= $0.last }) {
                hadithChapter = ch
            } else if let ch = await HadithAPI.shared.chapterContaining(book: slug, number: number) {
                hadithChapter = ch
            } else if let first = book.chapters.first {
                // Still open something useful
                hadithChapter = first
                startNumber = number
            } else {
                error = "Could not locate kitāb for #\(number)."
            }
            return
        }

        error = "This reminder has no link."
    }
}
