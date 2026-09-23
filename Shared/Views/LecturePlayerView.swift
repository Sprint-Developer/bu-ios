import SwiftUI
import AVFoundation

// MARK: - Player skins

private enum PlayerSkinKind: String, CaseIterable, Identifiable {
    case dark, light, soundcloud
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark: return "Night"
        case .light: return "Day"
        case .soundcloud: return "SoundCloud"
        }
    }
    var symbol: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .soundcloud: return "waveform"
        }
    }
}

private struct PlayerSkin {
    let kind: PlayerSkinKind
    let isDark: Bool
    let bgTop: Color
    let bgBottom: Color
    let blobA: Color
    let blobB: Color
    let card: Color
    let cardStroke: Color
    let ink: Color
    let inkSecondary: Color
    let accent: Color
    let accentSoft: Color
    let controlFill: Color
    let barTrack: Color
    let barFill: Color
    /// SoundCloud-style: square cover, orange waveform, less vinyl spin.
    var soundCloudLayout: Bool { kind == .soundcloud }

    static let dark = PlayerSkin(
        kind: .dark,
        isDark: true,
        bgTop: Color(red: 0.06, green: 0.07, blue: 0.10),
        bgBottom: Color(red: 0.02, green: 0.03, blue: 0.05),
        blobA: Color(red: 0.15, green: 0.45, blue: 0.42).opacity(0.55),
        blobB: Color(red: 0.55, green: 0.35, blue: 0.15).opacity(0.40),
        card: Color.white.opacity(0.08),
        cardStroke: Color.white.opacity(0.12),
        ink: .white,
        inkSecondary: .white.opacity(0.55),
        accent: Color(red: 0.85, green: 0.70, blue: 0.38),
        accentSoft: Color(red: 0.85, green: 0.70, blue: 0.38).opacity(0.22),
        controlFill: Color.white.opacity(0.10),
        barTrack: Color.white.opacity(0.15),
        barFill: Color(red: 0.85, green: 0.70, blue: 0.38)
    )

    static let light = PlayerSkin(
        kind: .light,
        isDark: false,
        bgTop: Color(red: 0.97, green: 0.95, blue: 0.91),
        bgBottom: Color(red: 0.92, green: 0.94, blue: 0.96),
        blobA: Color(red: 0.20, green: 0.55, blue: 0.50).opacity(0.28),
        blobB: Color(red: 0.85, green: 0.60, blue: 0.30).opacity(0.22),
        card: Color.white.opacity(0.78),
        cardStroke: Color.black.opacity(0.06),
        ink: Color(red: 0.12, green: 0.12, blue: 0.14),
        inkSecondary: Color(red: 0.40, green: 0.40, blue: 0.44),
        accent: Color(red: 0.10, green: 0.42, blue: 0.40),
        accentSoft: Color(red: 0.10, green: 0.42, blue: 0.40).opacity(0.14),
        controlFill: Color.black.opacity(0.05),
        barTrack: Color.black.opacity(0.10),
        barFill: Color(red: 0.10, green: 0.42, blue: 0.40)
    )

    /// Classic SoundCloud orange on near-white.
    static let soundcloud = PlayerSkin(
        kind: .soundcloud,
        isDark: false,
        bgTop: Color(red: 0.98, green: 0.98, blue: 0.97),
        bgBottom: Color(red: 0.94, green: 0.94, blue: 0.93),
        blobA: Color(red: 1.0, green: 0.33, blue: 0.0).opacity(0.12),
        blobB: Color(red: 0.15, green: 0.15, blue: 0.18).opacity(0.06),
        card: Color.white,
        cardStroke: Color.black.opacity(0.06),
        ink: Color(red: 0.13, green: 0.13, blue: 0.14),
        inkSecondary: Color(red: 0.45, green: 0.45, blue: 0.47),
        accent: Color(red: 1.0, green: 0.33, blue: 0.0), // #FF5500
        accentSoft: Color(red: 1.0, green: 0.33, blue: 0.0).opacity(0.14),
        controlFill: Color(red: 0.95, green: 0.95, blue: 0.94),
        barTrack: Color(red: 0.88, green: 0.88, blue: 0.87),
        barFill: Color(red: 1.0, green: 0.33, blue: 0.0)
    )

    static func skin(for kind: PlayerSkinKind) -> PlayerSkin {
        switch kind {
        case .dark: return .dark
        case .light: return .light
        case .soundcloud: return .soundcloud
        }
    }
}

/// Full-screen lecture player bound to `LectureAudioSession.shared`.
struct LecturePlayerView: View {
    var fallbackTranscript: String = ""
    var initialLang: SubtitleLang = .english

    @ObservedObject private var session = LectureAudioSession.shared
    @State private var subtitleLang: SubtitleLang = .english
    @State private var appear = false
    @State private var discAngle: Double = 0
    @State private var showSync = false
    @State private var showShare = false
    @State private var bookmarkFlash = false
    @AppStorage("beummati.player.skin") private var skinKindRaw = PlayerSkinKind.dark.rawValue
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var reading: ReadingSettings
    @EnvironmentObject private var bookmarks: BookmarkStore
    @StateObject private var notes = NotesStore()
    @ObservedObject private var theme = ThemeStore.shared

    private var skinKind: PlayerSkinKind {
        PlayerSkinKind(rawValue: skinKindRaw) ?? .dark
    }

    private var skin: PlayerSkin { PlayerSkin.skin(for: skinKind) }

    private var np: LectureAudioSession.NowPlaying? { session.nowPlaying }

    private var availableLangs: [SubtitleLang] {
        guard let np else { return [.english] }
        var langs: [SubtitleLang] = [.english]
        let meta = LibraryChapterMeta(
            id: np.chapterID,
            title: np.chapterTitle,
            srtEnglish: np.srtEnglish,
            srtUrdu: np.srtUrdu
        )
        if let u = np.srtUrdu, !u.isEmpty, SRTCueParser.bundleContainsSRT(u) {
            langs.append(.urdu)
        }
        if SRTCueParser.resolveFile(track: np.track, chapter: meta, lang: .english) != nil {
            langs.append(.arabic)
        }
        return langs
    }

    var body: some View {
        ZStack {
            playerBackground
            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: skin.soundCloudLayout ? 18 : 22) {
                        if skin.soundCloudLayout {
                            soundCloudArtwork
                                .padding(.top, 4)
                        } else {
                            artworkHero
                                .padding(.top, 8)
                        }
                        titleBlock
                        if availableLangs.count > 1 {
                            langPicker
                        }
                        subtitleStage
                        progressBlock
                        transport
                        extrasRow
                        if showSync { syncRow }
                        if !session.queue.isEmpty {
                            queueHint
                        }
                        Text(LectureAudioCatalog.attribution)
                            .font(.caption2)
                            .foregroundStyle(skin.inkSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
        .preferredColorScheme(skin.isDark ? .dark : .light)
        .navigationBarHidden(true)
        .onAppear {
            if availableLangs.contains(initialLang) { subtitleLang = initialLang }
            if abs(session.userSyncOffset) >= 0.05 { showSync = true }
            if UserDefaults.standard.object(forKey: "beummati.player.skin") == nil {
                if UserDefaults.standard.object(forKey: "beummati.player.darkSkin") != nil {
                    let dark = UserDefaults.standard.bool(forKey: "beummati.player.darkSkin")
                    skinKindRaw = dark ? PlayerSkinKind.dark.rawValue : PlayerSkinKind.light.rawValue
                } else {
                    skinKindRaw = theme.kind.isDark ? PlayerSkinKind.dark.rawValue : PlayerSkinKind.light.rawValue
                }
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) { appear = true }
            startDiscSpin()
        }
        .onChange(of: subtitleLang) { _, lang in
            session.reloadSubtitles(lang: lang, fallback: fallbackTranscript)
        }
        .onChange(of: session.isPlaying) { _, playing in
            if playing { startDiscSpin() }
        }
        .sheet(isPresented: $showShare) {
            if let snap = session.momentSnapshot(), let np {
                ShareCardStudioView(
                    title: snap.title,
                    kind: "Lecture",
                    ref: "\(np.seriesTitle) · \(np.chapterTitle)",
                    arabic: SRTCueParser.isPrimarilyRTL(snap.body) ? snap.body : "",
                    english: SRTCueParser.isPrimarilyRTL(snap.body) ? "" : snap.body,
                    urdu: "",
                    mode: .text
                )
                .environmentObject(reading)
            }
        }
    }

    // MARK: Background

    private var playerBackground: some View {
        ZStack {
            LinearGradient(colors: [skin.bgTop, skin.bgBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            // Static blobs only — animated TimelineView was expensive.
            Circle()
                .fill(skin.blobA)
                .frame(width: skin.soundCloudLayout ? 380 : 320, height: skin.soundCloudLayout ? 380 : 320)
                .blur(radius: skin.soundCloudLayout ? 80 : 60)
                .offset(x: -80, y: -160)
                .opacity(appear ? 0.9 : 0)
            Circle()
                .fill(skin.blobB)
                .frame(width: 280, height: 280)
                .blur(radius: 55)
                .offset(x: 100, y: 180)
                .opacity(appear ? (skin.soundCloudLayout ? 0.5 : 0.85) : 0)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button {
                session.showFullPlayer = false
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(skin.ink)
                    .frame(width: 40, height: 40)
                    .background(skin.controlFill, in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Now playing")
                    .font(BeUmmatiTheme.ui(12, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(skin.inkSecondary)
                if session.listeningStreakDays > 0 {
                    Text("\(session.listeningStreakDays)-day listen streak")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(skin.accent)
                }
            }
            Spacer()
            Menu {
                ForEach(PlayerSkinKind.allCases) { kind in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            skinKindRaw = kind.rawValue
                        }
                    } label: {
                        Label(kind.label, systemImage: kind.symbol)
                        if skinKind == kind {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Image(systemName: skinKind.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(skin.accent)
                    .frame(width: 40, height: 40)
                    .background(skin.controlFill, in: Circle())
                    .symbolEffect(.bounce, value: skinKindRaw)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: SoundCloud artwork

    private var soundCloudArtwork: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.18, blue: 0.20),
                        Color(red: 0.08, green: 0.08, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: np?.seriesIcon ?? "waveform")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            )
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0 ..< 28, id: \.self) { i in
                        let h = 4 + abs(sin(Double(i) * 0.7)) * 18
                        Capsule()
                            .fill(skin.accent.opacity(session.isPlaying ? 0.95 : 0.55))
                            .frame(width: 3, height: session.isPlaying ? h + CGFloat(i % 3) * 2 : h)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .shadow(color: skin.accent.opacity(session.isPlaying ? 0.35 : 0.12), radius: 20, y: 10)
            .scaleEffect(appear ? 1 : 0.94)
            .opacity(appear ? 1 : 0)
    }

    // MARK: Artwork (vinyl)

    private var artworkHero: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [skin.accent.opacity(0.1), skin.accent, skin.blobA, skin.accent.opacity(0.1)],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 236, height: 236)
                .rotationEffect(.degrees(session.isPlaying ? discAngle : discAngle * 0.2))
                .opacity(0.85)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: skin.isDark
                                ? [Color(red: 0.12, green: 0.14, blue: 0.18), Color(red: 0.08, green: 0.09, blue: 0.12)]
                                : [Color.white, Color(red: 0.93, green: 0.94, blue: 0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: skin.accent.opacity(skin.isDark ? 0.35 : 0.25), radius: session.isPlaying ? 28 : 14, y: 10)

                ForEach(0 ..< 4, id: \.self) { i in
                    Circle()
                        .stroke(skin.ink.opacity(skin.isDark ? 0.06 : 0.05), lineWidth: 1)
                        .padding(CGFloat(28 + i * 16))
                }

                Circle()
                    .fill(skin.accent.opacity(0.92))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: np?.seriesIcon ?? "waveform")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(skin.isDark ? Color(red: 0.08, green: 0.08, blue: 0.1) : .white)
                    )
                    .shadow(color: skin.accent.opacity(0.45), radius: 12, y: 4)
            }
            .frame(width: 210, height: 210)
            .rotationEffect(.degrees(session.isPlaying ? discAngle : 0))
            .scaleEffect(appear ? 1 : 0.82)
            .opacity(appear ? 1 : 0)

            equalizerBars
                .offset(y: 128)
        }
        .frame(height: 270)
    }

    private var equalizerBars: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 12, id: \.self) { i in
                let h: CGFloat = session.isPlaying ? (8 + CGFloat((i * 7) % 18)) : 5
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(skin.accent.opacity(0.55))
                    .frame(width: 5, height: h)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .opacity(0.95)
    }

    // MARK: Titles

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(np?.chapterTitle ?? "Lecture")
                .font(BeUmmatiTheme.heading(skin.soundCloudLayout ? 20 : 22))
                .foregroundStyle(skin.ink)
                .multilineTextAlignment(skin.soundCloudLayout ? .leading : .center)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: skin.soundCloudLayout ? .leading : .center)
            Text(np?.seriesTitle ?? "")
                .font(BeUmmatiTheme.ui(14, weight: .medium))
                .foregroundStyle(skin.inkSecondary)
                .frame(maxWidth: .infinity, alignment: skin.soundCloudLayout ? .leading : .center)
            if !session.subtitleSourceLabel.isEmpty {
                Text(session.subtitleSourceLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(skin.accent.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: skin.soundCloudLayout ? .leading : .center)
            }
        }
        .offset(y: appear ? 0 : 12)
        .opacity(appear ? 1 : 0)
    }

    private var langPicker: some View {
        HStack(spacing: 8) {
            ForEach(availableLangs) { lang in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        subtitleLang = lang
                    }
                } label: {
                    Text(lang.label)
                        .font(BeUmmatiTheme.ui(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(subtitleLang == lang ? skin.accent : skin.controlFill)
                        )
                        .foregroundStyle(subtitleLang == lang ? (skin.isDark ? Color(red: 0.1, green: 0.1, blue: 0.12) : .white) : skin.ink)
                }
                .buttonStyle(.plain)
            }
            if skin.soundCloudLayout { Spacer(minLength: 0) }
        }
    }

    // MARK: Subtitles

    @ViewBuilder
    private var subtitleStage: some View {
        let cue = session.activeCue
        let rtl = cue.map { SRTCueParser.isPrimarilyRTL($0.text) } ?? (subtitleLang != .english)
        ZStack {
            RoundedRectangle(cornerRadius: skin.soundCloudLayout ? 12 : 22, style: .continuous)
                .fill(skin.card)
                .overlay(
                    RoundedRectangle(cornerRadius: skin.soundCloudLayout ? 12 : 22, style: .continuous)
                        .stroke(skin.cardStroke, lineWidth: 1)
                )
                .shadow(color: .black.opacity(skin.isDark ? 0.35 : 0.08), radius: skin.soundCloudLayout ? 8 : 18, y: 8)

            Group {
                if let cue {
                    Text(cue.text)
                        .font(fontForCue(cue.text))
                        .foregroundStyle(skin.ink)
                        .multilineTextAlignment(rtl ? .trailing : (skin.soundCloudLayout ? .leading : .center))
                        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                        .lineSpacing(5)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: rtl ? .trailing : (skin.soundCloudLayout ? .leading : .center))
                        .id(cue.id)
                        .transition(.opacity)
                } else if !session.isReady {
                    ProgressView().tint(skin.accent)
                } else if session.cues.isEmpty {
                    Text("No timed subtitles for this lecture yet")
                        .font(BeUmmatiTheme.ui(14))
                        .foregroundStyle(skin.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(20)
                } else {
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundStyle(skin.inkSecondary.opacity(0.35))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: cue?.id)
        }
        .frame(minHeight: 140)
    }

    // MARK: Progress

    private var progressBlock: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let progress = session.duration > 0 ? min(1, max(0, session.currentTime / session.duration)) : 0
                ZStack(alignment: .leading) {
                    waveformStrip(width: w, active: false)
                    waveformStrip(width: w, active: true)
                        .mask(
                            Rectangle()
                                .frame(width: max(2, w * progress))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                    if !skin.soundCloudLayout {
                        Circle()
                            .fill(skin.accent)
                            .frame(width: 14, height: 14)
                            .shadow(color: skin.accent.opacity(0.5), radius: 6, y: 2)
                            .offset(x: max(0, w * progress - 7))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let p = min(1, max(0, value.location.x / max(w, 1)))
                            session.seek(to: p * max(session.duration, 1))
                        }
                )
            }
            .frame(height: skin.soundCloudLayout ? 56 : 44)

            HStack {
                Text(Self.format(session.currentTime))
                Spacer()
                Button {
                    withAnimation { showSync.toggle() }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(skin.inkSecondary)
                }
                Spacer()
                Text(Self.format(session.duration))
            }
            .font(BeUmmatiTheme.ui(11, weight: .semibold).monospacedDigit())
            .foregroundStyle(skin.inkSecondary)
        }
    }

    private func waveformStrip(width: CGFloat, active: Bool) -> some View {
        let spacing: CGFloat = skin.soundCloudLayout ? 1.5 : 2
        let barW: CGFloat = skin.soundCloudLayout ? 2 : 2.5
        let count = max(40, Int(width / (barW + spacing)))
        return HStack(alignment: .center, spacing: spacing) {
            ForEach(0 ..< count, id: \.self) { i in
                let seed = abs(sin(Double(i) * 1.7)) * 0.5 + 0.5
                let h = (skin.soundCloudLayout ? 10 : 8) + seed * (skin.soundCloudLayout ? 36 : 28)
                Capsule()
                    .fill(active ? skin.barFill : skin.barTrack)
                    .frame(width: barW, height: h)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Transport

    private var transport: some View {
        HStack(spacing: skin.soundCloudLayout ? 28 : 36) {
            Button { session.skip(by: -15) } label: {
                Image(systemName: "gobackward.15")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(skin.ink)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(BounceButtonStyle())

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                    session.togglePlay()
                }
            } label: {
                ZStack {
                    if skin.soundCloudLayout {
                        Circle()
                            .fill(skin.accent)
                            .frame(width: 64, height: 64)
                        Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: session.isPlaying ? 0 : 2)
                    } else {
                        Circle()
                            .fill(skin.accent)
                            .frame(width: 78, height: 78)
                            .shadow(color: skin.accent.opacity(0.45), radius: session.isPlaying ? 18 : 10, y: 6)
                        Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(skin.isDark ? Color(red: 0.08, green: 0.08, blue: 0.1) : .white)
                            .offset(x: session.isPlaying ? 0 : 2)
                    }
                }
                .scaleEffect(session.isPlaying ? 1.0 : 1.04)
            }
            .buttonStyle(BounceButtonStyle())

            Button { session.skip(by: 15) } label: {
                Image(systemName: "goforward.15")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(skin.ink)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(BounceButtonStyle())
        }
        .padding(.vertical, 6)
    }

    private var extrasRow: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(LectureAudioSession.rates, id: \.self) { r in
                    Button {
                        session.setRate(r)
                    } label: {
                        HStack {
                            Text(r == 1 ? "1×" : String(format: "%.2g×", r))
                            if abs(session.rate - r) < 0.01 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                extraChip(icon: "gauge.with.dots.needle.33percent", title: String(format: "%.2g×", session.rate))
            }

            Menu {
                ForEach(LectureAudioSession.SleepOption.allCases) { opt in
                    Button {
                        session.setSleep(opt)
                    } label: {
                        HStack {
                            Text(opt.label)
                            if session.sleep == opt {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                extraChip(
                    icon: "moon.zzz",
                    title: session.sleep == .off ? "Sleep" : session.sleep.label
                )
            }

            Button { bookmarkMoment() } label: {
                extraChip(icon: bookmarkFlash ? "bookmark.fill" : "bookmark", title: "Moment")
            }

            Button { showShare = true } label: {
                extraChip(icon: "square.and.arrow.up", title: "Clip")
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showSync.toggle()
                }
            } label: {
                extraChip(
                    icon: "timeline.selection",
                    title: abs(session.userSyncOffset) < 0.05
                        ? "Sync"
                        : String(format: "%+.1fs", session.userSyncOffset)
                )
            }

            if let track = np?.track {
                Button {
                    Task {
                        if session.isDownloaded(track) {
                            session.removeDownload(track)
                        } else {
                            await session.download(track)
                        }
                    }
                } label: {
                    let done = session.isDownloaded(track) || (session.downloadProgress[track.id] ?? 0) >= 1
                    let mid = session.downloadProgress[track.id]
                    extraChip(
                        icon: done ? "checkmark.circle.fill" : "arrow.down.circle",
                        title: mid != nil && mid! > 0 && mid! < 1 ? "…" : (done ? "Saved" : "Save")
                    )
                }
            }
        }
    }

    private func extraChip(icon: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(skin.ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(skin.controlFill, in: RoundedRectangle(cornerRadius: skin.soundCloudLayout ? 8 : 14, style: .continuous))
    }

    private var queueHint: some View {
        HStack {
            Image(systemName: "list.bullet")
            Text("\(session.queue.count) more in queue")
            Spacer()
            Button("Skip to next") { session.playNextInQueue() }
                .font(.caption.weight(.bold))
                .foregroundStyle(skin.accent)
        }
        .font(BeUmmatiTheme.ui(13, weight: .medium))
        .foregroundStyle(skin.inkSecondary)
        .padding(12)
        .background(skin.controlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var syncRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Subtitle timing")
                    .font(BeUmmatiTheme.ui(13, weight: .bold))
                    .foregroundStyle(skin.ink)
                Spacer()
                Text(abs(session.userSyncOffset) < 0.05
                     ? "Matched"
                     : String(format: "%+.1fs", session.userSyncOffset))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(skin.inkSecondary)
                if abs(session.userSyncOffset) >= 0.05 {
                    Button("Reset") { session.resetSyncOffset() }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(skin.accent)
                }
            }
            Text("If lines appear too soon, tap Later. Saved for this series.")
                .font(.caption2)
                .foregroundStyle(skin.inkSecondary)
            HStack(spacing: 8) {
                syncNudgeButton(title: "Earlier", detail: "−1s", delta: -1)
                syncNudgeButton(title: "−0.25", detail: nil, delta: -0.25)
                syncNudgeButton(title: "+0.25", detail: nil, delta: 0.25)
                syncNudgeButton(title: "Later", detail: "+1s", delta: 1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(skin.controlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func syncNudgeButton(title: String, detail: String?, delta: TimeInterval) -> some View {
        Button {
            session.nudgeSync(by: delta)
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                if let detail {
                    Text(detail)
                        .font(.caption2.weight(.semibold))
                        .opacity(0.7)
                }
            }
            .foregroundStyle(skin.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(skin.bgTop.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func bookmarkMoment() {
        guard let snap = session.momentSnapshot() else { return }
        notes.add(title: snap.title, body: snap.body, ref: snap.ref, tags: ["lecture", "moment"], linkKind: "Lecture")
        if !bookmarks.isBookmarked(kind: "Lecture", ref: snap.ref) {
            bookmarks.toggle(
                kind: "Lecture",
                ref: snap.ref,
                title: snap.title,
                arabic: "",
                english: snap.body,
                urdu: ""
            )
        }
        withAnimation { bookmarkFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { bookmarkFlash = false }
        }
    }

    private func startDiscSpin() {
        guard session.isPlaying, !skin.soundCloudLayout else { return }
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            discAngle += 360
        }
    }

    private func fontForCue(_ text: String) -> Font {
        let rtl = SRTCueParser.isPrimarilyRTL(text)
        if subtitleLang == .urdu || (rtl && subtitleLang != .english) {
            if subtitleLang == .urdu { return reading.urduFont.font(size: 16) }
            return reading.arabicFont.font(size: 17)
        }
        if rtl { return reading.arabicFont.font(size: 16) }
        return BeUmmatiTheme.ui(15, weight: .medium)
    }

    private static func format(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let s = Int(t.rounded())
        let m = s / 60
        let r = s % 60
        if m >= 60 { return String(format: "%d:%02d:%02d", m / 60, m % 60, r) }
        return String(format: "%d:%02d", m, r)
    }
}

private struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: configuration.isPressed)
    }
}
