import SwiftUI

struct DuasLibraryView: View {
    @State private var query = ""

    private var filteredCategories: [DuaCategory] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return HisnAlMuslim.categories }
        return HisnAlMuslim.categories.filter {
            $0.titleEn.lowercased().contains(q)
                || $0.titleAr.contains(query)
                || $0.duas.contains { $0.english.lowercased().contains(q) || $0.arabic.contains(query) }
        }
    }

    var body: some View {
        List {
            Section {
                Text("\(HisnAlMuslim.allDuas.count) authentic duas & adhkar from Hisn al-Muslim, each with a classical reference. Unsourced lines are not included.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Quick access") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(HisnAlMuslim.shortcuts) { s in
                                NavigationLink {
                                    DuaShortcutListView(shortcut: s)
                                } label: {
                                    Text(s.title)
                                        .font(BeUmmatiTheme.ui(13, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(BeUmmatiTheme.tealSoft, in: Capsule())
                                        .foregroundStyle(BeUmmatiTheme.teal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let hits = HisnAlMuslim.search(query)
                Section("Matches (\(hits.count))") {
                    ForEach(hits) { dua in
                        NavigationLink {
                            DuaDetailView(dua: dua, categoryTitle: HisnAlMuslim.category(id: dua.categoryId)?.titleEn ?? "")
                        } label: {
                            duaRow(dua)
                        }
                    }
                }
            }

            Section("All chapters (\(filteredCategories.count))") {
                ForEach(filteredCategories) { cat in
                    NavigationLink {
                        DuaCategoryView(category: cat)
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(cat.id)")
                                .font(BeUmmatiTheme.ui(12, weight: .bold))
                                .foregroundStyle(BeUmmatiTheme.brass)
                                .frame(width: 28, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(cat.titleEn)
                                    .font(BeUmmatiTheme.heading(16))
                                Text(cat.titleAr)
                                    .font(BeUmmatiTheme.ui(13))
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                                    .environment(\.layoutDirection, .rightToLeft)
                            }
                            Spacer()
                            Text("\(cat.duas.count)")
                                .font(BeUmmatiTheme.ui(13, weight: .bold))
                                .foregroundStyle(BeUmmatiTheme.brass)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                Text(HisnAlMuslim.source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
        .navigationTitle("Duas & Adhkar")
        .searchable(text: $query, prompt: "Search duas")
    }

    private func duaRow(_ dua: DuaItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dua.arabic)
                .font(BeUmmatiTheme.ui(17))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .lineLimit(2)
            Text(dua.english)
                .font(BeUmmatiTheme.ui(13))
                .foregroundStyle(BeUmmatiTheme.inkSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

struct DuaShortcutListView: View {
    let shortcut: DuaShortcut

    private var cats: [DuaCategory] {
        let set = Set(shortcut.categoryIds)
        return HisnAlMuslim.categories.filter { set.contains($0.id) }
    }

    var body: some View {
        List {
            ForEach(cats) { cat in
                Section(cat.titleEn) {
                    ForEach(cat.duas) { dua in
                        NavigationLink {
                            DuaDetailView(dua: dua, categoryTitle: cat.titleEn)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(dua.arabic)
                                    .font(BeUmmatiTheme.ui(18))
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .environment(\.layoutDirection, .rightToLeft)
                                    .lineLimit(3)
                                Text(dua.english)
                                    .font(BeUmmatiTheme.ui(13))
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
        .navigationTitle(shortcut.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DuaCategoryView: View {
    let category: DuaCategory

    var body: some View {
        List {
            Section {
                Text(category.titleAr)
                    .font(BeUmmatiTheme.heading(20))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            ForEach(category.duas) { dua in
                NavigationLink {
                    DuaDetailView(dua: dua, categoryTitle: category.titleEn)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dua.arabic)
                            .font(BeUmmatiTheme.ui(20))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text(dua.english)
                            .font(BeUmmatiTheme.ui(14))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            .lineLimit(3)
                        if dua.count > 1 {
                            Text("× \(dua.count)")
                                .font(BeUmmatiTheme.ui(12, weight: .bold))
                                .foregroundStyle(BeUmmatiTheme.brass)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(BeUmmatiTheme.parchment)
        .navigationTitle(category.titleEn)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DuaDetailView: View {
    let dua: DuaItem
    let categoryTitle: String
    @EnvironmentObject var reading: ReadingSettings
    @EnvironmentObject var bookmarks: BookmarkStore
    @StateObject private var notes = NotesStore()
    @State private var tapCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !categoryTitle.isEmpty {
                    Text(categoryTitle)
                        .font(BeUmmatiTheme.ui(12, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                }

                Text(dua.arabic)
                    .font(reading.arabicFont.font(size: reading.arabicSize + 4))
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .lineSpacing(reading.arabicLineSpacing)
                    .padding(16)
                    .beUmmatiCard()

                if !dua.transliteration.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Transliteration")
                            .font(BeUmmatiTheme.ui(11, weight: .bold))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        Text(dua.transliteration)
                            .font(BeUmmatiTheme.ui(15))
                            .foregroundStyle(BeUmmatiTheme.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Meaning")
                        .font(BeUmmatiTheme.ui(11, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    Text(dua.english)
                        .font(reading.englishFont.font(size: reading.englishSize))
                        .lineSpacing(4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reference")
                        .font(BeUmmatiTheme.ui(11, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                    Text(dua.reference)
                        .font(BeUmmatiTheme.ui(13, weight: .semibold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                }

                if dua.count > 1 {
                    VStack(spacing: 10) {
                        Text("\(tapCount) / \(dua.count)")
                            .font(BeUmmatiTheme.heading(28))
                            .foregroundStyle(BeUmmatiTheme.teal)
                        ProgressView(value: Double(min(tapCount, dua.count)), total: Double(dua.count))
                            .tint(BeUmmatiTheme.brass)
                        Button {
                            tapCount = min(tapCount + 1, dua.count * 10)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("Tap to count")
                                .font(BeUmmatiTheme.ui(15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(BeUmmatiTheme.teal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        Button("Reset count") { tapCount = 0 }
                            .font(BeUmmatiTheme.ui(13, weight: .semibold))
                            .foregroundStyle(BeUmmatiTheme.teal)
                    }
                    .padding(.top, 8)
                }

                HStack(spacing: 12) {
                    BeUmmatiShareButton(
                        title: categoryTitle,
                        kind: "Dua",
                        ref: dua.reference,
                        arabic: dua.arabic,
                        english: dua.english,
                        urdu: ""
                    )
                    ShareCardButton(
                        kind: "Dua",
                        ref: dua.reference,
                        arabic: dua.arabic,
                        english: dua.english,
                        urdu: ""
                    )
                    Button {
                        notes.add(
                            title: categoryTitle.isEmpty ? "Dua" : categoryTitle,
                            body: "\(dua.arabic)\n\n\(dua.english)\n\n— \(dua.reference)",
                            ref: dua.reference,
                            linkKind: "Dua"
                        )
                    } label: {
                        Label("Note", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.plain)

                    Button {
                        bookmarks.toggle(
                            kind: "Dua",
                            ref: dua.id,
                            title: categoryTitle,
                            arabic: dua.arabic,
                            english: dua.english,
                            urdu: ""
                        )
                    } label: {
                        Image(systemName: bookmarks.isBookmarked(kind: "Dua", ref: dua.id) ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.plain)
                }
                .font(BeUmmatiTheme.ui(13, weight: .semibold))
                .foregroundStyle(BeUmmatiTheme.teal)
            }
            .padding(20)
        }
        .beUmmatiScreenBackground()
        .navigationTitle("Dua")
        .navigationBarTitleDisplayMode(.inline)
    }
}
