import SwiftUI

enum HadithReadMode: String, CaseIterable, Identifiable {
    case scroll = "Scroll"
    case slide = "Slide"
    var id: String { rawValue }
}

struct HadithListView: View {
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore

    var body: some View {
        NavigationStack {
            List(HadithAPI.catalog) { book in
                NavigationLink(value: book) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.name)
                                .font(BeUmmatiTheme.heading(17))
                                .foregroundStyle(BeUmmatiTheme.ink)
                            Text(book.hasUrdu ? "Arabic · English · Urdu" : "Arabic · English")
                                .font(BeUmmatiTheme.ui(12))
                                .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(book.hadithCount)")
                                .font(BeUmmatiTheme.ui(16, weight: .bold))
                                .foregroundStyle(BeUmmatiTheme.teal)
                            Text("hadith")
                                .font(BeUmmatiTheme.ui(10, weight: .medium))
                                .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .beUmmatiScreenBackground()
            .navigationTitle("Hadith")
            .navigationDestination(for: HadithBookInfo.self) { book in
                HadithChaptersView(book: book, notes: notes, bookmarks: bookmarks)
            }
        }
    }
}

struct HadithChaptersView: View {
    let book: HadithBookInfo
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @State private var jumpText = ""
    @State private var showJump = false
    @State private var jumpError: String?
    @State private var jumpTarget: JumpTarget?

    private struct JumpTarget: Hashable {
        let chapter: HadithChapter
        let number: Int
    }

    var body: some View {
        List {
            Section {
                Text("\(book.hadithCount) hadiths · \(book.chapters.count) books")
                    .font(BeUmmatiTheme.ui(13))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
            }
            Section("Books (kitāb)") {
                ForEach(book.chapters) { ch in
                    NavigationLink {
                        HadithReaderView(
                            book: book,
                            chapter: ch,
                            startNumber: ch.first,
                            notes: notes,
                            bookmarks: bookmarks
                        )
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(ch.index)")
                                .font(BeUmmatiTheme.ui(13, weight: .bold))
                                .foregroundStyle(BeUmmatiTheme.teal)
                                .frame(width: 28, alignment: .leading)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ch.name)
                                    .font(BeUmmatiTheme.ui(15, weight: .semibold))
                                    .foregroundStyle(BeUmmatiTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("#\(ch.first)–\(ch.last)")
                                    .font(BeUmmatiTheme.ui(11))
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            }
                            Spacer(minLength: 8)
                            Text("\(ch.count)")
                                .font(BeUmmatiTheme.ui(13, weight: .bold))
                                .foregroundStyle(BeUmmatiTheme.brass)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .beUmmatiScreenBackground()
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    jumpText = ""
                    jumpError = nil
                    showJump = true
                } label: {
                    Label("Go to", systemImage: "arrow.right.circle")
                }
            }
        }
        .alert("Go to hadith #", isPresented: $showJump) {
            TextField("Number", text: $jumpText)
                .keyboardType(.numberPad)
            Button("Go") { Task { await performJump() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(jumpError ?? "Enter a hadith number in \(book.name) (1–\(book.hadithCount)).")
        }
        .navigationDestination(item: $jumpTarget) { target in
            HadithReaderView(
                book: book,
                chapter: target.chapter,
                startNumber: target.number,
                notes: notes,
                bookmarks: bookmarks
            )
        }
    }

    private func performJump() async {
        guard let n = Int(jumpText.trimmingCharacters(in: .whitespaces)), n > 0 else {
            jumpError = "Enter a valid number."
            showJump = true
            return
        }
        if let ch = book.chapters.first(where: { n >= $0.first && n <= $0.last }) {
            jumpTarget = JumpTarget(chapter: ch, number: n)
            return
        }
        // Fallback: open nearest chapter if number exists in edition
        if let _ = try? await HadithAPI.shared.hadithByNumber(book: book.slug, number: n),
           let ch = book.chapters.min(by: { abs(($0.first + $0.last) / 2 - n) < abs(($1.first + $1.last) / 2 - n) }) {
            jumpTarget = JumpTarget(chapter: ch, number: n)
            return
        }
        jumpError = "Hadith #\(n) not found in \(book.name)."
        showJump = true
    }
}

struct HadithReaderView: View {
    let book: HadithBookInfo
    let chapter: HadithChapter
    let startNumber: Int
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @EnvironmentObject var reading: ReadingSettings

    @State private var items: [HadithItem] = []
    @State private var loading = true
    @State private var error: String?
    @State private var pageIndex = 0
    @State private var jumpText = ""
    @State private var showJump = false
    @AppStorage("beummati.hadithReadMode") private var modeRaw = HadithReadMode.slide.rawValue

    private var mode: Binding<HadithReadMode> {
        Binding(
            get: { HadithReadMode(rawValue: modeRaw) ?? .slide },
            set: { modeRaw = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            if loading {
                ProgressView("Loading \(chapter.name)…")
            } else if let error {
                ContentUnavailableView("Couldn’t load", systemImage: "wifi.exclamationmark", description: Text(error))
            } else if items.isEmpty {
                ContentUnavailableView("No hadith", systemImage: "book.closed")
            } else if mode.wrappedValue == .slide {
                slideReader
            } else {
                scrollReader
            }
        }
        .beUmmatiScreenBackground()
        .navigationTitle(chapter.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button { showJump = true } label: {
                        Image(systemName: "arrow.right.circle")
                    }
                    Picker("Mode", selection: mode) {
                        ForEach(HadithReadMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .alert("Go to hadith #", isPresented: $showJump) {
            TextField("Number", text: $jumpText)
                .keyboardType(.numberPad)
            Button("Go") { jumpInChapter() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This book: #\(chapter.first)–\(chapter.last)")
        }
        .task { await load() }
    }

    private var slideReader: some View {
        VStack(spacing: 0) {
            TabView(selection: $pageIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, h in
                    ScrollView {
                        hadithCard(h)
                            .padding(16)
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                Button {
                    pageIndex = max(0, pageIndex - 1)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 28))
                }
                .disabled(pageIndex <= 0)

                Spacer()
                if items.indices.contains(pageIndex) {
                    Text("#\(items[pageIndex].number)  ·  \(pageIndex + 1)/\(items.count)")
                        .font(BeUmmatiTheme.ui(13, weight: .semibold))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                }
                Spacer()

                Button {
                    pageIndex = min(items.count - 1, pageIndex + 1)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 28))
                }
                .disabled(pageIndex >= items.count - 1)
            }
            .foregroundStyle(BeUmmatiTheme.teal)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(BeUmmatiTheme.parchmentDeep)
        }
    }

    private var scrollReader: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(items) { h in
                        hadithCard(h)
                            .id(h.number)
                    }
                }
                .padding(16)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    proxy.scrollTo(startNumber, anchor: .top)
                }
            }
            .onChange(of: pageIndex) { _, _ in
                if items.indices.contains(pageIndex) {
                    proxy.scrollTo(items[pageIndex].number, anchor: .top)
                }
            }
        }
    }

    private func hadithCard(_ h: HadithItem) -> some View {
        let ref = "\(book.name) #\(h.number)"
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("#\(h.number)")
                    .font(BeUmmatiTheme.ui(13, weight: .bold))
                    .foregroundStyle(BeUmmatiTheme.brass)
                Spacer()
                Text(chapter.name)
                    .font(BeUmmatiTheme.ui(11, weight: .medium))
                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    .lineLimit(1)
            }
            TripleText(arabic: h.arabic, english: h.english, urdu: h.urdu)
            HStack {
                BeUmmatiShareButton(kind: "Hadith", ref: ref, arabic: h.arabic, english: h.english, urdu: h.urdu)
                GiftReminderButton(kind: "Hadith", ref: ref, arabic: h.arabic, english: h.english, urdu: h.urdu)
                Button {
                    notes.add(title: ref, body: "\(h.arabic)\n\n\(h.english)\n\n\(h.urdu)", ref: "\(book.slug):\(h.number)", linkKind: "Hadith")
                } label: {
                    Label("Note", systemImage: "square.and.pencil")
                }
                .buttonStyle(.plain)
                Button {
                    bookmarks.toggle(kind: "Hadith", ref: ref, title: ref, arabic: h.arabic, english: h.english, urdu: h.urdu)
                } label: {
                    Label(
                        bookmarks.isBookmarked(kind: "Hadith", ref: ref) ? "Saved" : "Save",
                        systemImage: bookmarks.isBookmarked(kind: "Hadith", ref: ref) ? "bookmark.fill" : "bookmark"
                    )
                }
                .buttonStyle(.plain)
            }
            .font(BeUmmatiTheme.ui(13, weight: .semibold))
            .foregroundStyle(BeUmmatiTheme.teal)
        }
        .padding(16)
        .beUmmatiCard()
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let loaded = try await HadithAPI.shared.chapter(book: book.slug, index: chapter.index)
            items = loaded
            if let idx = loaded.firstIndex(where: { $0.number == startNumber }) {
                pageIndex = idx
            } else if let idx = loaded.firstIndex(where: { $0.number >= startNumber }) {
                pageIndex = idx
            } else {
                pageIndex = 0
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func jumpInChapter() {
        guard let n = Int(jumpText.trimmingCharacters(in: .whitespaces)) else { return }
        if let idx = items.firstIndex(where: { $0.number == n }) {
            pageIndex = idx
        } else if let idx = items.firstIndex(where: { $0.number >= n }) {
            pageIndex = idx
        }
    }
}
