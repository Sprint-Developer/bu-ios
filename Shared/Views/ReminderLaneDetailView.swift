import SwiftUI

/// Full-page view for one home reminder lane (Qur’an / Hadith / Quotes / Dhikr).
struct ReminderLaneDetailView: View {
    let lane: ReminderLane
    @ObservedObject var reminders: ReminderStore
    @ObservedObject var notes: NotesStore
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var plan: DailyPlanStore
    @EnvironmentObject var reading: ReadingSettings

    private var item: ReminderItem? { reminders.item(for: lane) }

    var body: some View {
        Group {
            if let item {
                detail(item)
            } else {
                ContentUnavailableView(
                    "No reminder yet",
                    systemImage: lane.icon,
                    description: Text("Tap Next to load a \(lane.rawValue.lowercased()) reminder.")
                )
                Button("Next") { reminders.refresh(lane: lane) }
                    .buttonStyle(.borderedProminent)
                    .tint(BeUmmatiTheme.teal)
            }
        }
        .beUmmatiScreenBackground()
        .navigationTitle("\(lane.rawValue) reminder")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func detail(_ item: ReminderItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label(lane.rawValue, systemImage: lane.icon)
                        .font(BeUmmatiTheme.ui(13, weight: .bold))
                        .foregroundStyle(BeUmmatiTheme.brass)
                    Spacer()
                    Text(item.ref)
                        .font(BeUmmatiTheme.ui(12, weight: .medium))
                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                        .multilineTextAlignment(.trailing)
                }

                if !item.title.isEmpty {
                    Text(item.title)
                        .font(BeUmmatiTheme.heading(24))
                }

                TripleText(arabic: item.arabic, english: item.english, urdu: item.urdu)

                if canOpenSource(item) {
                    NavigationLink {
                        ReminderDestinationView(item: item, notes: notes, bookmarks: bookmarks, plan: plan)
                    } label: {
                        openSourceLabel(item)
                    }
                    .buttonStyle(.plain)
                } else if let seriesID = item.librarySeriesID,
                          let chapterID = item.libraryChapterID,
                          let series = LibraryCatalog.series(id: seriesID),
                          let chapter = series.chapters?.first(where: { $0.id == chapterID }) {
                    NavigationLink {
                        LibraryChapterReaderView(series: series, chapter: chapter)
                    } label: {
                        rowButton(title: "Open full lecture", systemImage: "waveform.and.mic")
                    }
                    .buttonStyle(.plain)
                } else if let duaID = item.duaID,
                          let dua = HisnAlMuslim.allDuas.first(where: { $0.id == duaID }) {
                    NavigationLink {
                        DuaDetailView(
                            dua: dua,
                            categoryTitle: HisnAlMuslim.category(id: dua.categoryId)?.titleEn ?? lane.rawValue
                        )
                    } label: {
                        rowButton(title: "Open full dua", systemImage: "hands.sparkles.fill")
                    }
                    .buttonStyle(.plain)
                } else if let sid = item.scholarID, let profile = ScholarQuotes.profile(id: sid) {
                    NavigationLink {
                        ScholarDetailView(scholar: profile)
                    } label: {
                        rowButton(title: "Open \(profile.name)", systemImage: "person.fill")
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    BeUmmatiShareButton(
                        title: item.title.isEmpty ? nil : item.title,
                        kind: item.kind,
                        ref: item.ref,
                        arabic: item.arabic,
                        english: item.english,
                        urdu: item.urdu
                    )
                    ShareCardButton(
                        title: item.title.isEmpty ? nil : item.title,
                        kind: item.kind,
                        ref: item.ref,
                        arabic: item.arabic,
                        english: item.english,
                        urdu: item.urdu
                    )
                    GiftReminderButton(
                        title: item.title.isEmpty ? nil : item.title,
                        kind: item.kind,
                        ref: item.ref,
                        arabic: item.arabic,
                        english: item.english,
                        urdu: item.urdu
                    )
                    Button {
                        bookmarks.toggle(
                            kind: item.kind, ref: item.ref, title: item.title,
                            arabic: item.arabic, english: item.english, urdu: item.urdu
                        )
                    } label: {
                        Label(
                            bookmarks.isBookmarked(kind: item.kind, ref: item.ref) ? "Saved" : "Save",
                            systemImage: bookmarks.isBookmarked(kind: item.kind, ref: item.ref) ? "bookmark.fill" : "bookmark"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .font(BeUmmatiTheme.ui(13, weight: .semibold))
                .foregroundStyle(BeUmmatiTheme.teal)

                Button {
                    reminders.refresh(lane: lane)
                } label: {
                    Label("Next \(lane.rawValue.lowercased()) reminder", systemImage: "arrow.triangle.2.circlepath")
                        .font(BeUmmatiTheme.ui(15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(BeUmmatiTheme.tealSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(BeUmmatiTheme.teal)
            }
            .padding(20)
        }
    }

    private func canOpenSource(_ item: ReminderItem) -> Bool {
        item.quranKey != nil || (item.hadithBook != nil && item.hadithNumber != nil)
    }

    private func openSourceLabel(_ item: ReminderItem) -> some View {
        rowButton(
            title: item.quranKey != nil ? "Open ayah \(item.ref)" : "Open hadith \(item.ref)",
            systemImage: item.quranKey != nil ? "book.fill" : "text.book.closed.fill"
        )
    }

    private func rowButton(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
        }
        .font(BeUmmatiTheme.ui(14, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(BeUmmatiTheme.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
