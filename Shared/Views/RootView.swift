import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var reminders = ReminderStore()
    @StateObject private var notes = NotesStore()
    @StateObject private var bookmarks = BookmarkStore()
    @StateObject private var plan = DailyPlanStore()
    @ObservedObject private var prayer = PrayerService.shared
    @StateObject private var reading = ReadingSettings()
    @StateObject private var salah = SalahTracker()
    @ObservedObject private var notify = PrayerNotifications.shared
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var deepLink = LibraryDeepLink.shared
    @ObservedObject private var player = LecturePlayerPresentation.shared
    @State private var tab = 0
    @State private var deepLinkSheet: LibraryDeepLink.Target?

    var body: some View {
        TabView(selection: $tab) {
            HomeView(reminders: reminders, notes: notes, bookmarks: bookmarks, plan: plan, prayer: prayer, reading: reading, notify: notify, salah: salah)
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(0)

            QuranListView(notes: notes, bookmarks: bookmarks, plan: plan)
                .tabItem { Label("Qur’an", systemImage: "book") }
                .tag(1)

            HadithListView(notes: notes, bookmarks: bookmarks)
                .tabItem { Label("Hadith", systemImage: "text.book.closed") }
                .tag(2)

            ReadingLibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(3)

            ScholarsLibraryView()
                .tabItem { Label("Scholars", systemImage: "person.3") }
                .tag(4)

            SavedHub(bookmarks: bookmarks, notes: notes)
                .tabItem { Label("Saved", systemImage: "bookmark") }
                .tag(5)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerBar()
        }
        .environmentObject(reading)
        .environmentObject(bookmarks)
        .environmentObject(theme)
        .tint(BeUmmatiTheme.teal)
        .preferredColorScheme(theme.appearance.colorScheme ?? (theme.kind.isDark ? .dark : nil))
        .id(theme.kind.rawValue + "|" + theme.appearance.rawValue)
        .onAppear {
            reading.ensureManuscriptDefaults()
            plan.rollIfNeeded()
            reminders.refresh()
            prayer.refresh()
            consumeDeepLink()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                plan.rollIfNeeded()
                reminders.refresh()
                notify.reschedule(day: prayer.day)
                consumeDeepLink()
            }
        }
        .onChange(of: tab) { _, new in
            if new == 0 { reminders.refresh() }
        }
        .onChange(of: deepLink.pending) { _, _ in
            consumeDeepLink()
        }
        .sheet(isPresented: $player.showFull) {
            NavigationStack {
                LecturePlayerView()
            }
            .environmentObject(reading)
            .environmentObject(bookmarks)
            .environmentObject(theme)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $deepLinkSheet) { target in
            if let series = LibraryCatalog.series(id: target.seriesID),
               let chapter = series.chapters?.first(where: { $0.id == target.chapterID }) {
                NavigationStack {
                    LibraryChapterReaderView(series: series, chapter: chapter)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { deepLinkSheet = nil }
                            }
                        }
                }
                .environmentObject(reading)
                .environmentObject(bookmarks)
                .environmentObject(theme)
            } else {
                Text("Lecture not found")
                    .padding()
            }
        }
    }

    private func consumeDeepLink() {
        guard let pending = deepLink.pending else { return }
        deepLink.clear()
        tab = 3
        deepLinkSheet = pending
    }
}

struct SavedHub: View {
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var notes: NotesStore
    @State private var segment = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $segment) {
                    Text("Bookmarks").tag(0)
                    Text("Notes").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if segment == 0 {
                    BookmarksView(bookmarks: bookmarks, notes: notes)
                } else {
                    NotesView(notes: notes)
                }
            }
            .beUmmatiScreenBackground()
            .navigationTitle("Saved")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        MoreSettings()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }
}

/// Settings previously under More — still reachable from Saved gear + Today.
struct MoreSettings: View {
    @EnvironmentObject var reading: ReadingSettings
    @EnvironmentObject var bookmarks: BookmarkStore
    @StateObject private var notes = NotesStore()
    @ObservedObject private var prayer = PrayerService.shared
    @StateObject private var salah = SalahTracker()
    @ObservedObject private var notify = PrayerNotifications.shared
    @ObservedObject private var theme = ThemeStore.shared
    @AppStorage("beummati.displayName") private var displayName = ""

    var body: some View {
        List {
            Section {
                TextField("Your name", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                Text("Shown on Home as Assalamu alaikum wa rehmatullahi wa barakatuh + your name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Profile")
            }

            Section {
                NavigationLink {
                    ReadingSettingsView(settings: reading)
                } label: {
                    Label("Reading settings", systemImage: "textformat.size")
                }
                NavigationLink {
                    ThemeSettingsView(theme: theme)
                } label: {
                    Label("Theme", systemImage: "paintpalette")
                }
            } header: {
                Text("Reading & look")
            } footer: {
                Text("Theme: \(theme.kind.title). Manuscript, Midnight, Emerald, Ocean, Ummati, Soft Day.")
            }

            Section {
                NavigationLink {
                    PrayerNotifySettingsView(notify: notify, prayer: prayer)
                } label: {
                    Label("Prayer notifications", systemImage: "bell.badge")
                }
                NavigationLink {
                    PrayerView(prayer: prayer, notify: notify)
                } label: {
                    Label("Prayer times", systemImage: "clock")
                }
                NavigationLink {
                    QiblaView()
                } label: {
                    Label("Qibla", systemImage: "location.north.line")
                }
                NavigationLink {
                    CalendarView(prayer: prayer)
                } label: {
                    Label("Islamic calendar", systemImage: "calendar")
                }
            } header: {
                Text("Reminders & prayer")
            } footer: {
                Text(notify.enabled ? "Prayer alerts on · \(notify.authStatus)" : "Prayer alerts off")
            }

            Section("Practice") {
                NavigationLink {
                    HifzView()
                } label: {
                    Label("Hifz", systemImage: "brain.head.profile")
                }
                NavigationLink {
                    SalahTrackerView(tracker: salah)
                } label: {
                    Label("Salah tracker", systemImage: "checkmark.circle")
                }
                NavigationLink {
                    DuasLibraryView()
                } label: {
                    Label("Duas & Adhkar", systemImage: "hands.sparkles")
                }
                NavigationLink {
                    DhikrView()
                } label: {
                    Label("Dhikr counter", systemImage: "circle.grid.cross")
                }
            }

            Section("Find & offline") {
                NavigationLink {
                    SearchView(notes: notes, bookmarks: bookmarks)
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                NavigationLink {
                    ScholarsQuotesView()
                } label: {
                    Label("Scholars", systemImage: "person.3")
                }
                NavigationLink {
                    OfflinePackView()
                } label: {
                    Label("Offline data", systemImage: "arrow.down.circle")
                }
            }

            Section("About") {
                LabeledContent(AppIdentity.brand, value: AppIdentity.versionLabel)
                    .font(.system(size: 14))
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            prayer.refresh()
            notify.refreshAuth()
        }
    }
}
