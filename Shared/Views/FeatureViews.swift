import SwiftUI

struct BookmarksView: View {
    @ObservedObject var bookmarks: BookmarkStore
    @ObservedObject var notes: NotesStore
    @EnvironmentObject var reading: ReadingSettings

    var body: some View {
        Group {
            if bookmarks.items.isEmpty {
                ContentUnavailableView(
                    "No bookmarks",
                    systemImage: "bookmark",
                    description: Text("Star an ayah, hadith, or reminder to pin it here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(bookmarks.items) { item in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(item.ref)
                                        .font(BeUmmatiTheme.ui(12, weight: .bold))
                                        .foregroundStyle(BeUmmatiTheme.brass)
                                    Spacer()
                                    Text(relativeDate(item.created))
                                        .font(BeUmmatiTheme.ui(11))
                                        .foregroundStyle(BeUmmatiTheme.inkSecondary)
                                }
                                if !item.title.isEmpty {
                                    Text(item.title).font(BeUmmatiTheme.heading(17))
                                }
                                TripleText(arabic: item.arabic, english: item.english, urdu: item.urdu)
                                HStack {
                                    BeUmmatiShareButton(title: item.title, kind: item.kind, ref: item.ref, arabic: item.arabic, english: item.english, urdu: item.urdu)
                                    Button {
                                        notes.add(title: item.title.isEmpty ? "\(item.kind) \(item.ref)" : item.title, body: ShareText.compose(title: item.title, kind: item.kind, ref: item.ref, arabic: item.arabic, english: item.english, urdu: item.urdu, reading: reading), ref: item.ref, linkKind: item.kind)
                                    } label: {
                                        Label("Note", systemImage: "square.and.pencil")
                                    }
                                    .buttonStyle(.plain)
                                    Spacer()
                                    Button {
                                        bookmarks.remove(item)
                                    } label: {
                                        Image(systemName: "bookmark.slash")
                                    }
                                    .buttonStyle(.plain)
                                }
                                .font(BeUmmatiTheme.ui(13, weight: .semibold))
                                .foregroundStyle(BeUmmatiTheme.teal)
                            }
                            .padding(16)
                            .beUmmatiCard()
                        }
                    }
                    .padding(16)
                }
            }
        }
        .beUmmatiScreenBackground()
        .navigationTitle("Bookmarks")
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

struct OfflinePackView: View {
    @ObservedObject private var packs = OfflinePacks.shared
    @State private var cachedSurahs: [Int] = []
    @State private var textBytes: Int64 = 0
    @State private var audioBytes: Int64 = 0

    var body: some View {
        List {
            Section {
                Text("Download once for fast / offline reading. Hisn al-Muslim, Sahaba, and scholars quotes are already in the app. Tafsir Ibn Kathir (Urdu) ships bundled.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                LabeledContent("Qur’an text", value: "\(cachedSurahs.count)/114 · \(Self.format(textBytes))")
                LabeledContent("Qur’an audio", value: Self.format(audioBytes))
                if packs.busy {
                    Button(role: .cancel) {
                        packs.cancel()
                    } label: {
                        Label("Cancel download", systemImage: "xmark.circle")
                    }
                }
            }

            Section("Packs") {
                ForEach(packs.packs) { row in
                    packRow(row)
                }
            }

            if !cachedSurahs.isEmpty {
                Section("Qur’an surahs offline") {
                    ForEach(cachedSurahs, id: \.self) { id in
                        HStack {
                            Text("Surah \(id)")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.42))
                        }
                    }
                }
            }
        }
        .navigationTitle("Offline data")
        .task { await refresh() }
        .onChange(of: packs.busy) { _, _ in
            Task { await refresh() }
        }
    }

    @ViewBuilder
    private func packRow(_ row: OfflinePackState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.pack.label).font(.headline)
                    Text("\(row.pack.blurb) (\(row.pack.sizeHint))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge(row)
            }
            if case .downloading = row.status {
                ProgressView(value: row.progress)
                    .tint(Color(red: 0.15, green: 0.55, blue: 0.42))
                if !row.detail.isEmpty {
                    Text(row.detail).font(.caption2).foregroundStyle(.secondary)
                }
            }
            HStack {
                if row.status != .ready && !packs.busy {
                    Button("Download") {
                        packs.download([row.pack])
                    }
                    .buttonStyle(.borderedProminent)
                }
                if row.status == .ready {
                    Button("Remove", role: .destructive) {
                        packs.remove(row.pack)
                        Task { await refresh() }
                    }
                }
                if case .failed(let msg) = row.status {
                    Text(msg).font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statusBadge(_ row: OfflinePackState) -> some View {
        switch row.status {
        case .ready:
            Text("Ready").font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.42))
        case .downloading:
            Text("Downloading…").font(.caption).foregroundStyle(.secondary)
        case .failed:
            Text("Failed").font(.caption).foregroundStyle(.red)
        case .notDownloaded:
            Text("Not on device").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func refresh() async {
        cachedSurahs = await OfflineCache.shared.cachedSurahIDs()
        textBytes = await OfflineCache.shared.approximateBytes()
        audioBytes = await QuranAudioCache.shared.approximateBytes()
        packs.refreshStatuses()
    }

    private static func format(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}

struct QiblaView: View {
    @StateObject private var qibla = QiblaService()

    var body: some View {
        VStack(spacing: 28) {
            Text(qibla.status)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 18)
                    .frame(width: 240, height: 240)
                ForEach(["N", "E", "S", "W"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .offset(y: label == "N" ? -118 : label == "S" ? 118 : 0)
                        .offset(x: label == "E" ? 118 : label == "W" ? -118 : 0)
                }
                Image(systemName: "location.north.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 0.15, green: 0.55, blue: 0.42))
                    .rotationEffect(.degrees(qibla.needleRotation))
                    .animation(.easeOut(duration: 0.15), value: qibla.needleRotation)
            }

            VStack(spacing: 6) {
                Text(String(format: "Qibla bearing %.0f°", qibla.qiblaBearing))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Hold the phone flat; turn until the arrow points up.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(24)
        .navigationTitle("Qibla")
        .onAppear { qibla.start() }
        .onDisappear { qibla.stop() }
    }
}

struct PrayerNotifySettingsView: View {
    @ObservedObject var notify: PrayerNotifications
    @ObservedObject var prayer: PrayerService

    var body: some View {
        Form {
            Section {
                Toggle("Prayer alerts", isOn: Binding(
                    get: { notify.enabled },
                    set: { on in Task { await notify.setEnabled(on); notify.reschedule(day: prayer.day) } }
                ))
                Text(notify.authStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Which prayers") {
                Toggle("Fajr", isOn: $notify.fajr)
                Toggle("Dhuhr", isOn: $notify.dhuhr)
                Toggle("Asr", isOn: $notify.asr)
                Toggle("Maghrib", isOn: $notify.maghrib)
                Toggle("Isha", isOn: $notify.isha)
            }
            Section("Remind before") {
                Stepper("\(notify.preMinutes) minutes", value: $notify.preMinutes, in: 0...60, step: 5)
            }
            Section {
                Toggle("Daily reminder", isOn: Binding(
                    get: { notify.dailyReminder },
                    set: { on in Task { await notify.setDailyReminder(on); notify.reschedule(day: prayer.day) } }
                ))
                if notify.dailyReminder {
                    Stepper("Hour \(notify.dailyHour):\(String(format: "%02d", notify.dailyMinute))", value: $notify.dailyHour, in: 0...23)
                    Stepper("Minute \(String(format: "%02d", notify.dailyMinute))", value: $notify.dailyMinute, in: 0...55, step: 5)
                }
                Text("One gentle ping a day — prefers your Series reminder snippet and can open that lecture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Reschedule for today") {
                    notify.saveToggles()
                    notify.reschedule(day: prayer.day)
                }
            }
        }
        .navigationTitle("Notifications")
        .onChange(of: notify.fajr) { _, _ in notify.saveToggles(); notify.reschedule(day: prayer.day) }
        .onChange(of: notify.dhuhr) { _, _ in notify.saveToggles(); notify.reschedule(day: prayer.day) }
        .onChange(of: notify.asr) { _, _ in notify.saveToggles(); notify.reschedule(day: prayer.day) }
        .onChange(of: notify.maghrib) { _, _ in notify.saveToggles(); notify.reschedule(day: prayer.day) }
        .onChange(of: notify.isha) { _, _ in notify.saveToggles(); notify.reschedule(day: prayer.day) }
        .onChange(of: notify.preMinutes) { _, _ in notify.saveToggles(); notify.reschedule(day: prayer.day) }
        .onChange(of: notify.dailyHour) { _, _ in notify.saveToggles(); notify.reschedule(day: prayer.day) }
        .onChange(of: notify.dailyMinute) { _, _ in notify.saveToggles(); notify.reschedule(day: prayer.day) }
        .onAppear { notify.refreshAuth() }
    }
}

struct DhikrView: View {
    @AppStorage("beummati.dhikr.count") private var count = 0
    @AppStorage("beummati.dhikr.target") private var target = 33
    @State private var phrase = "سُبْحَانَ ٱللَّٰهِ"

    private let phrases = [
        "سُبْحَانَ ٱللَّٰهِ",
        "ٱلْحَمْدُ لِلَّٰهِ",
        "ٱللَّٰهُ أَكْبَرُ",
        "لَا إِلَٰهَ إِلَّا ٱللَّٰهُ"
    ]

    var body: some View {
        VStack(spacing: 28) {
            Picker("Dhikr", selection: $phrase) {
                ForEach(phrases, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Text(phrase)
                .font(.custom("Amiri-Regular", size: 36))
                .multilineTextAlignment(.center)
                .foregroundStyle(BeUmmatiTheme.ink)
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity)
                .padding()

            Text("\(count)")
                .font(BeUmmatiTheme.heading(64))
                .foregroundStyle(BeUmmatiTheme.teal)

            Text("of \(target)")
                .font(BeUmmatiTheme.ui(14, weight: .medium))
                .foregroundStyle(BeUmmatiTheme.inkSecondary)

            ProgressView(value: Double(count % max(target, 1)), total: Double(max(target, 1)))
                .tint(BeUmmatiTheme.brass)
                .padding(.horizontal, 40)

            Button {
                count += 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Text("Tap")
                    .font(BeUmmatiTheme.heading(22))
                    .foregroundStyle(.white)
                    .frame(width: 140, height: 140)
                    .background(BeUmmatiTheme.teal, in: Circle())
                    .shadow(color: BeUmmatiTheme.teal.opacity(0.35), radius: 16, y: 8)
            }
            .buttonStyle(.plain)

            HStack(spacing: 20) {
                Button("Reset") { count = 0 }
                Stepper("Target \(target)", value: $target, in: 11...100, step: 11)
            }
            .font(BeUmmatiTheme.ui(14, weight: .semibold))
            .foregroundStyle(BeUmmatiTheme.teal)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 24)
        .beUmmatiScreenBackground()
        .navigationTitle("Dhikr")
    }
}
