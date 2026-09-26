import Foundation
import AVFoundation
import CoreAudio
import MediaPlayer
import MediaToolbox
import Combine
import UIKit

/// Whether the full player sheet is up. Kept off `LectureAudioSession` so screens that only
/// care about presentation (RootView's sheet, the mini bar) aren't invalidated by playback ticks.
@MainActor
final class LecturePlayerPresentation: ObservableObject {
    static let shared = LecturePlayerPresentation()
    @Published var showFull = false
    private init() {}
}

/// One shared lecture audio engine — mini player, lock screen, queue, downloads, streak.
@MainActor
final class LectureAudioSession: ObservableObject {
    static let shared = LectureAudioSession()

    struct NowPlaying: Equatable {
        var seriesID: String
        var chapterID: String
        var seriesTitle: String
        var chapterTitle: String
        var seriesIcon: String
        var track: LectureAudioTrack
        var srtEnglish: String?
        var srtUrdu: String?
    }

    enum SleepOption: String, CaseIterable, Identifiable {
        case off, m15, m30, m45, endOfLecture
        var id: String { rawValue }
        var label: String {
            switch self {
            case .off: return "Off"
            case .m15: return "15 min"
            case .m30: return "30 min"
            case .m45: return "45 min"
            case .endOfLecture: return "End of lecture"
            }
        }
        /// Fits the player's chip row, where "End of lecture" would truncate.
        var shortLabel: String {
            switch self {
            case .off: return "Sleep"
            case .m15: return "15m"
            case .m30: return "30m"
            case .m45: return "45m"
            case .endOfLecture: return "End"
            }
        }
        var minutes: Int? {
            switch self {
            case .off, .endOfLecture: return nil
            case .m15: return 15
            case .m30: return 30
            case .m45: return 45
            }
        }
    }

    static let rates: [Float] = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5]

    @Published var nowPlaying: NowPlaying?
    @Published var isPlaying = false
    @Published var isReady = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 1
    @Published var rate: Float = 1.0
    @Published var sleep: SleepOption = .off
    @Published var sleepEndsAt: Date?
    @Published var cues: [SRTCue] = []
    @Published var activeCue: SRTCue?
    @Published var subtitleSourceLabel = ""
    @Published var userSyncOffset: TimeInterval = 0
    @Published var downloadProgress: [String: Double] = [:] // track id → 0...1 or 1 = done
    @Published var queue: [NowPlaying] = []
    @Published private(set) var listeningStreakDays = 0

    /// Proxy so existing call sites keep working while the flag lives elsewhere.
    var showFullPlayer: Bool {
        get { LecturePlayerPresentation.shared.showFull }
        set { LecturePlayerPresentation.shared.showFull = newValue }
    }

    /// Keep at 0 — Al Qalam SRTs are timed to speech onset; a positive lead makes lines feel early.
    private let presentationLead: TimeInterval = 0
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var sleepTimer: Timer?
    private var rawCues: [SRTCue] = []
    private var autoAlignOffset: TimeInterval = 0
    private var didAutoAlign = false
    private var didSynthesize = false
    private var pendingFallback = ""
    private var pendingResumeTime: TimeInterval?
    private var remoteConfigured = false
    private var lastPersistedSecond: Int = -1
    private var lastPublishedTime: TimeInterval = -1
    private var cueLoadGeneration = 0
    /// Unpublished playhead at the full observer rate — cue matching needs the precision
    /// that the throttled `currentTime` no longer carries.
    private var mediaTime: TimeInterval = 0
    /// Soft gain for quiet archive masters (BOJ ≈ −17 dB vs Seerah).
    private var gainController = LectureAudioGainController()
    private var attachedPlayerItem: AVPlayerItem?

    private let streakKey = "beummati.lecture.streak"
    private let lastListenDayKey = "beummati.lecture.lastListenDay"
    private let lastSessionKey = "beummati.lecture.lastSession"
    private let rateKey = "beummati.lecture.rate"

    private init() {
        let savedRate = UserDefaults.standard.float(forKey: rateKey)
        if Self.rates.contains(savedRate) { rate = savedRate }
        loadStreak()
        configureRemoteCommandsIfNeeded()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Play

    func play(
        series: LibrarySeries,
        chapter: LibraryChapterMeta,
        track: LectureAudioTrack,
        lang: SubtitleLang = .english,
        fallbackTranscript: String = "",
        enqueueRestOfSeries: Bool = true
    ) {
        QuranAyahPlayer.shared.pause()
        let item = NowPlaying(
            seriesID: series.id,
            chapterID: chapter.id,
            seriesTitle: series.title,
            chapterTitle: chapter.title,
            seriesIcon: series.icon,
            track: track,
            srtEnglish: chapter.srtEnglish,
            srtUrdu: chapter.srtUrdu
        )
        nowPlaying = item
        pendingFallback = fallbackTranscript
        didSynthesize = false
        didAutoAlign = false
        autoAlignOffset = 0
        userSyncOffset = Self.savedSyncOffset(for: series.id)
        pendingResumeTime = nil
        if let last = lastSession(),
           last.seriesID == series.id,
           last.chapterID == chapter.id,
           last.time > 8 {
            pendingResumeTime = last.time
        }

        let file = resolveFile(for: item, lang: lang)
        loadCues(file: file, lang: lang)
        startPlayer(urlString: localOrRemoteURL(for: track))

        if enqueueRestOfSeries {
            rebuildQueue(from: series, after: chapter)
        }

        LibraryProgressStore.shared.mark(seriesID: series.id, chapterID: chapter.id)
        persistLastSession()
        touchListeningStreak()
    }

    func playNextInQueue() {
        guard !queue.isEmpty else { return }
        let next = queue.removeFirst()
        guard let series = LibraryCatalog.series(id: next.seriesID),
              let chapter = series.chapters?.first(where: { $0.id == next.chapterID })
        else { return }
        play(
            series: series,
            chapter: chapter,
            track: next.track,
            fallbackTranscript: "",
            enqueueRestOfSeries: false
        )
    }

    private func rebuildQueue(from series: LibrarySeries, after chapter: LibraryChapterMeta) {
        guard let chapters = series.chapters,
              let idx = chapters.firstIndex(where: { $0.id == chapter.id })
        else {
            queue = []
            return
        }
        var nextItems: [NowPlaying] = []
        for ch in chapters.suffix(from: chapters.index(after: idx)) {
            guard let t = LectureAudioCatalog.track(seriesID: series.id, chapterID: ch.id) else { continue }
            nextItems.append(NowPlaying(
                seriesID: series.id,
                chapterID: ch.id,
                seriesTitle: series.title,
                chapterTitle: ch.title,
                seriesIcon: series.icon,
                track: t,
                srtEnglish: ch.srtEnglish,
                srtUrdu: ch.srtUrdu
            ))
        }
        queue = nextItems
    }

    // MARK: - Transport

    func togglePlay() {
        guard let player else { return }
        if player.rate > 0 {
            pause()
        } else {
            QuranAyahPlayer.shared.pause()
            player.rate = rate
            isPlaying = true
            updateIdleTimer()
            updateNowPlayingInfo()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateIdleTimer()
        updateNowPlayingInfo()
    }

    func seek(to time: TimeInterval) {
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cm, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        mediaTime = time
        lastPublishedTime = time
        refreshActiveCue()
        updateNowPlayingInfo()
    }

    func skip(by delta: TimeInterval) {
        seek(to: min(max(0, currentTime + delta), max(duration, 1)))
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        UserDefaults.standard.set(newRate, forKey: rateKey)
        if isPlaying { player?.rate = newRate }
        // Re-map cue windows for display against wall-clock? We keep cue times in media time
        // (AVPlayer currentTime is media time, independent of rate) — no rescale needed.
        updateNowPlayingInfo()
    }

    func setSleep(_ option: SleepOption) {
        sleep = option
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepEndsAt = nil
        guard option != .off else { return }
        if let mins = option.minutes {
            let end = Date().addingTimeInterval(TimeInterval(mins * 60))
            sleepEndsAt = end
            let timer = Timer(timeInterval: TimeInterval(mins * 60), repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.pause()
                    self?.sleep = .off
                    self?.sleepEndsAt = nil
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            sleepTimer = timer
        }
        // endOfLecture handled in itemDidFinish
    }

    func stopAndClear() {
        tearDownPlayer()
        nowPlaying = nil
        queue = []
        cues = []
        rawCues = []
        activeCue = nil
        currentTime = 0
        mediaTime = 0
        lastPublishedTime = -1
        isReady = false
        sleep = .off
        sleepEndsAt = nil
        sleepTimer?.invalidate()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Subtitles

    func reloadSubtitles(lang: SubtitleLang, fallback: String) {
        guard let item = nowPlaying else { return }
        pendingFallback = fallback
        didSynthesize = false
        didAutoAlign = false
        autoAlignOffset = 0
        let file = resolveFile(for: item, lang: lang)
        // Alignment runs once the parsed cues land.
        loadCues(file: file, lang: lang)
    }

    /// Shift subtitle timing relative to audio. Positive = show lines later (helps when SRT is ahead).
    func nudgeSync(by delta: TimeInterval) {
        setSyncOffset(userSyncOffset + delta)
    }

    func setSyncOffset(_ value: TimeInterval) {
        // Allow large corrections (some Al Qalam SRTs drift by minutes). 0.05s steps.
        userSyncOffset = min(600, max(-600, (value * 20).rounded() / 20))
        applyOffsets()
        if let sid = nowPlaying?.seriesID {
            Self.persistSyncOffset(userSyncOffset, for: sid)
        }
    }

    func resetSyncOffset() {
        setSyncOffset(0)
    }

    /// Keep the phone/iPad screen awake while a lecture is playing (incl. sleep → end of lecture).
    /// No-op on Mac Catalyst where the system idle timer does not apply the same way.
    private func updateIdleTimer() {
        #if targetEnvironment(macCatalyst)
        // Mac stays awake based on system prefs; don't fight the OS.
        #else
        // Keep awake while playing or buffering so brief stalls don't let the screen sleep.
        let buffering = player?.timeControlStatus == .waitingToPlayAtSpecifiedRate
        UIApplication.shared.isIdleTimerDisabled = isPlaying || (nowPlaying != nil && buffering)
        #endif
    }

    private static func syncDefaultsKey(for seriesID: String) -> String {
        "beummati.lecture.syncOffset.\(seriesID)"
    }

    private static func savedSyncOffset(for seriesID: String) -> TimeInterval {
        UserDefaults.standard.double(forKey: syncDefaultsKey(for: seriesID))
    }

    private static func persistSyncOffset(_ value: TimeInterval, for seriesID: String) {
        let key = syncDefaultsKey(for: seriesID)
        if abs(value) < 0.05 {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func resolveFile(for item: NowPlaying, lang: SubtitleLang) -> String? {
        let meta = LibraryChapterMeta(
            id: item.chapterID,
            title: item.chapterTitle,
            srtEnglish: item.srtEnglish,
            srtUrdu: item.srtUrdu
        )
        return SRTCueParser.resolveFile(track: item.track, chapter: meta, lang: lang)
    }

    /// Reading + regex-parsing a full lecture SRT is tens of milliseconds of work; doing it
    /// inline on the main actor stalled the tap that started playback. Parse off-thread and
    /// drop results from a superseded load.
    private func loadCues(file: String?, lang: SubtitleLang) {
        cueLoadGeneration += 1
        let generation = cueLoadGeneration
        rawCues = []
        cues = []
        activeCue = nil

        guard let file, !file.isEmpty else {
            subtitleSourceLabel = ""
            return
        }
        subtitleSourceLabel = "Loading subtitles…"
        Task.detached(priority: .userInitiated) { [weak self] in
            let loaded = SRTCueParser.load(named: file)
            guard let session = self else { return }
            await MainActor.run {
                session.applyLoadedCues(loaded, file: file, lang: lang, generation: generation)
            }
        }
    }

    private func applyLoadedCues(_ loaded: [SRTCue], file: String, lang: SubtitleLang, generation: Int) {
        guard generation == cueLoadGeneration else { return }
        var result = loaded
        if lang == .arabic, !loaded.isEmpty {
            result = loaded.map { cue in
                let filtered = Self.preferArabic(cue.text)
                return SRTCue(id: cue.id, start: cue.start, end: cue.end, text: filtered.isEmpty ? cue.text : filtered)
            }
            subtitleSourceLabel = "SRT · Arabic · \(result.count) cues"
        } else if lang == .urdu, file.lowercased().contains("urdu") || file.contains("سیرت") {
            subtitleSourceLabel = "SRT · Urdu · \(result.count) cues"
        } else if !result.isEmpty {
            subtitleSourceLabel = "SRT · \(result.count) cues"
        } else {
            subtitleSourceLabel = ""
        }
        rawCues = result
        applyOffsets()
        // Duration may have arrived while we were parsing.
        alignCuesIfNeeded()
        synthesizeIfNeeded()
    }

    private static func preferArabic(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if lines.count > 1 {
            let ar = lines.filter { SRTCueParser.isPrimarilyRTL($0) }
            if !ar.isEmpty { return ar.joined(separator: "\n") }
        }
        return text
    }

    // MARK: - AVPlayer

    private func startPlayer(urlString: String) {
        tearDownPlayer()
        let playURL: URL
        if urlString.hasPrefix("/") {
            playURL = URL(fileURLWithPath: urlString)
        } else if urlString.hasPrefix("file:") {
            guard let u = URL(string: urlString) else { return }
            playURL = u
        } else {
            guard let u = URL(string: urlString) else { return }
            playURL = u
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { }

        // Prefer smoother streaming over tiny buffers (reduces pause/hitch feel).
        let item = AVPlayerItem(url: playURL)
        item.preferredForwardBufferDuration = 12
        attachedPlayerItem = item
        // BOJ archive rips are much quieter than Seerah / Abu Bakr (~−43 dB vs ~−26 dB).
        let boostDB: Float = (nowPlaying?.seriesID == "anwar-boj") ? 15 : 0
        gainController.attach(to: item, gainDB: boostDB)
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = true
        p.volume = 1
        player = p

        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.status == .readyToPlay {
                    let d = item.duration.seconds
                    if d.isFinite, d > 0 {
                        self.duration = d
                        self.isReady = true
                        self.synthesizeIfNeeded()
                        self.alignCuesIfNeeded()
                        if let resume = self.pendingResumeTime, resume > 0, resume < d - 5 {
                            self.pendingResumeTime = nil
                            self.seek(to: resume)
                        }
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }

        // ~8 Hz is enough for cue sync + scrubber without thrashing SwiftUI.
        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.125, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            MainActor.assumeIsolated {
                let t = time.seconds.isFinite ? time.seconds : 0
                // Cue sync keeps the full observer rate via `mediaTime`; the published
                // scrubber value only needs quarter-second steps, and every publish
                // redraws every screen observing this session.
                self.mediaTime = t
                if abs(t - self.lastPublishedTime) >= 0.25 {
                    self.lastPublishedTime = t
                    self.currentTime = t
                }
                if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0, abs(d - self.duration) > 0.5 {
                    self.duration = d
                    self.isReady = true
                    self.synthesizeIfNeeded()
                    self.alignCuesIfNeeded()
                }
                self.refreshActiveCue()
                let playing = p.rate > 0
                if self.isPlaying != playing {
                    self.isPlaying = playing
                    self.updateIdleTimer()
                }
                let sec = Int(t)
                if sec != self.lastPersistedSecond, sec % 5 == 0 {
                    self.lastPersistedSecond = sec
                    self.updateNowPlayingInfo()
                    self.persistLastSession()
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.itemDidFinish()
            }
        }

        p.rate = rate
        isPlaying = true
        updateIdleTimer()
        updateNowPlayingInfo()
    }

    private func itemDidFinish() {
        isPlaying = false
        updateIdleTimer()
        activeCue = nil
        if let np = nowPlaying {
            LibraryProgressStore.shared.markCompleted(seriesID: np.seriesID, chapterID: np.chapterID)
            LectureListenStats.shared.recordFinished(seriesID: np.seriesID, chapterID: np.chapterID)
        }
        if sleep == .endOfLecture {
            sleep = .off
            sleepEndsAt = nil
            updateNowPlayingInfo()
            return
        }
        if !queue.isEmpty {
            playNextInQueue()
        } else {
            updateNowPlayingInfo()
        }
    }

    private func tearDownPlayer() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObserver?.invalidate()
        statusObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        gainController.detach(from: attachedPlayerItem)
        attachedPlayerItem = nil
        player?.pause()
        player = nil
        isPlaying = false
        updateIdleTimer()
    }

    private func alignCuesIfNeeded() {
        guard !didAutoAlign, !rawCues.isEmpty, duration > 30 else { return }
        let result = SRTCueParser.alignToAudioDuration(rawCues, audioDuration: duration)
        didAutoAlign = true
        autoAlignOffset = result.offsetApplied
        applyOffsets()
        if result.offsetApplied != 0 {
            subtitleSourceLabel += String(format: " · auto-sync %+.0fs", result.offsetApplied)
        }
    }

    private func applyOffsets() {
        let total = autoAlignOffset + userSyncOffset
        if abs(total) < 0.001 {
            cues = rawCues
        } else {
            cues = rawCues.enumerated().map { i, c in
                SRTCue(
                    id: i,
                    start: max(0, c.start + total),
                    end: max(max(0, c.start + total) + 0.25, c.end + total),
                    text: c.text
                )
            }
        }
        refreshActiveCue()
    }

    private func refreshActiveCue() {
        let next = SRTCueParser.activeCue(in: cues, at: mediaTime + presentationLead)
        if next?.id != activeCue?.id { activeCue = next }
    }

    private func synthesizeIfNeeded() {
        guard cues.isEmpty, rawCues.isEmpty, !didSynthesize, duration > 5 else { return }
        let text = pendingFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 80 else { return }
        didSynthesize = true
        let built = SRTCueParser.synthesize(from: text, duration: duration)
        rawCues = built
        cues = built
        subtitleSourceLabel = cues.isEmpty ? "" : "Approx. transcript · \(cues.count) lines"
        refreshActiveCue()
    }

    // MARK: - Offline

    private var downloadRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LectureAudio", isDirectory: true)
    }

    func isDownloaded(_ track: LectureAudioTrack) -> Bool {
        FileManager.default.fileExists(atPath: localFileURL(for: track).path)
    }

    func localFileURL(for track: LectureAudioTrack) -> URL {
        let name = track.audioName ?? "\(track.seriesID)_\(track.chapterID).mp3"
        let safe = name.replacingOccurrences(of: "/", with: "_")
        return downloadRoot.appendingPathComponent(safe)
    }

    func localOrRemoteURL(for track: LectureAudioTrack) -> String {
        let local = localFileURL(for: track)
        if FileManager.default.fileExists(atPath: local.path) {
            return local.absoluteString
        }
        return track.audioUrl
    }

    func download(_ track: LectureAudioTrack) async {
        let id = track.id
        if isDownloaded(track) {
            downloadProgress[id] = 1
            return
        }
        guard let url = URL(string: track.audioUrl) else { return }
        downloadProgress[id] = 0.05
        do {
            try FileManager.default.createDirectory(at: downloadRoot, withIntermediateDirectories: true)
            let (temp, resp) = try await URLSession.shared.download(from: url)
            guard let http = resp as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
                downloadProgress[id] = 0
                return
            }
            let dest = localFileURL(for: track)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: temp, to: dest)
            // Also copy SRT beside it if present in bundle
            if let srt = track.srtFile {
                let cues = SRTCueParser.load(named: srt)
                if !cues.isEmpty {
                    let srtDest = dest.deletingPathExtension().appendingPathExtension("srt")
                    // Keep reference only — cues load from bundle; optional write not required
                    _ = srtDest
                }
            }
            downloadProgress[id] = 1
        } catch {
            downloadProgress[id] = 0
        }
    }

    func removeDownload(_ track: LectureAudioTrack) {
        let url = localFileURL(for: track)
        try? FileManager.default.removeItem(at: url)
        downloadProgress[track.id] = nil
    }

    // MARK: - Now Playing / Remote

    private func configureRemoteCommandsIfNeeded() {
        guard !remoteConfigured else { return }
        remoteConfigured = true
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                QuranAyahPlayer.shared.pause()
                player.rate = self.rate
                self.isPlaying = true
                self.updateIdleTimer()
                self.updateNowPlayingInfo()
            }
            // Only succeed when a player exists; otherwise leave idle timer alone.
            return (self?.player != nil) ? .success : .noActionableNowPlayingItem
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlay() }
            return .success
        }
        cc.skipForwardCommand.preferredIntervals = [15]
        cc.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: 15) }
            return .success
        }
        cc.skipBackwardCommand.preferredIntervals = [15]
        cc.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: -15) }
            return .success
        }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let np = nowPlaying else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: np.chapterTitle,
            MPMediaItemPropertyArtist: np.seriesTitle,
            MPMediaItemPropertyAlbumTitle: "Be Ummati",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(rate)
        ]
        // Simple artwork from tinted icon
        if let img = UIImage(systemName: np.seriesIcon) {
            let size = CGSize(width: 512, height: 512)
            let renderer = UIGraphicsImageRenderer(size: size)
            let art = renderer.image { ctx in
                UIColor(red: 0.10, green: 0.28, blue: 0.29, alpha: 1).setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                let conf = UIImage.SymbolConfiguration(pointSize: 180, weight: .semibold)
                let symbol = img.withConfiguration(conf).withTintColor(.white, renderingMode: .alwaysOriginal)
                let rect = CGRect(x: (512 - 220) / 2, y: (512 - 220) / 2, width: 220, height: 220)
                symbol.draw(in: rect)
            }
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: size) { _ in art }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Streak / last session

    private func loadStreak() {
        let d = UserDefaults.standard
        listeningStreakDays = d.integer(forKey: streakKey)
    }

    private func touchListeningStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let d = UserDefaults.standard
        let last = d.object(forKey: lastListenDayKey) as? Date
        if let last {
            let lastDay = cal.startOfDay(for: last)
            let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 0 {
                // already counted today
            } else if diff == 1 {
                listeningStreakDays = max(1, listeningStreakDays + 1)
            } else {
                listeningStreakDays = 1
            }
        } else {
            listeningStreakDays = 1
        }
        d.set(today, forKey: lastListenDayKey)
        d.set(listeningStreakDays, forKey: streakKey)
    }

    private func persistLastSession() {
        guard let np = nowPlaying else { return }
        let payload: [String: Any] = [
            "seriesID": np.seriesID,
            "chapterID": np.chapterID,
            "time": currentTime,
            "updated": Date().timeIntervalSince1970
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            UserDefaults.standard.set(data, forKey: lastSessionKey)
        }
    }

    func lastSession() -> (seriesID: String, chapterID: String, time: TimeInterval)? {
        guard let data = UserDefaults.standard.data(forKey: lastSessionKey),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let s = obj["seriesID"] as? String,
              let c = obj["chapterID"] as? String,
              let t = obj["time"] as? TimeInterval
        else { return nil }
        return (s, c, t)
    }

    /// Current subtitle line + timestamp for notes / share.
    func momentSnapshot() -> (title: String, body: String, ref: String)? {
        guard let np = nowPlaying else { return nil }
        let t = Self.format(currentTime)
        let line = activeCue?.text ?? ""
        let body = line.isEmpty
            ? "Listening at \(t)"
            : "[\(t)]\n\(line)"
        return (
            "\(np.chapterTitle) · \(t)",
            body,
            "\(np.seriesID)/\(np.chapterID)@\(Int(currentTime))"
        )
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

// MARK: - Soft gain for quiet lecture masters

/// Applies a gentle linear gain via `MTAudioProcessingTap` (AVPlayer volume maxes at 1×).
final class LectureAudioGainController {
    private var linearGain: Float = 1
    private var tap: MTAudioProcessingTap?
    /// Bumped on every attach/detach so a slow track load can't install a tap for a track
    /// the listener already skipped past.
    private var generation = 0

    func detach(from item: AVPlayerItem?) {
        generation += 1
        item?.audioMix = nil
        tap = nil
        linearGain = 1
    }

    func attach(to item: AVPlayerItem, gainDB: Float) {
        detach(from: item)
        guard gainDB > 0.5 else { return }
        linearGain = pow(10, gainDB / 20)
        let expected = generation

        Task { [weak self] in
            guard let controller = self else { return }
            do {
                let tracks = try await item.asset.loadTracks(withMediaType: .audio)
                guard let track = tracks.first else { return }
                await MainActor.run {
                    guard controller.generation == expected else { return }
                    controller.installTap(on: item, track: track)
                }
            } catch { }
        }
    }

    private func installTap(on item: AVPlayerItem, track: AVAssetTrack) {
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(self).toOpaque(),
            init: { _, clientInfo, tapStorageOut in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { _ in },
            prepare: { _, _, _ in },
            unprepare: { _ in },
            process: { tap, numberFrames, _, bufferListInOut, numberFramesOut, flagsOut in
                let status = MTAudioProcessingTapGetSourceAudio(
                    tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut
                )
                guard status == noErr else { return }
                let storage = MTAudioProcessingTapGetStorage(tap)
                let ctrl = Unmanaged<LectureAudioGainController>.fromOpaque(storage).takeUnretainedValue()
                let g = ctrl.linearGain
                guard abs(g - 1) > 0.01 else { return }
                let abl = UnsafeMutableAudioBufferListPointer(bufferListInOut)
                for buf in abl {
                    guard let data = buf.mData, buf.mDataByteSize > 0 else { continue }
                    // Processing format is typically non-interleaved Float32.
                    let count = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
                    let ptr = data.assumingMemoryBound(to: Float.self)
                    for i in 0 ..< count {
                        let v = ptr[i] * g
                        ptr[i] = max(-1, min(1, v))
                    }
                }
            }
        )

        var tapRef: MTAudioProcessingTap?
        let err = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tapRef
        )
        guard err == noErr, let created = tapRef else { return }
        tap = created

        let params = AVMutableAudioMixInputParameters(track: track)
        params.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        item.audioMix = mix
    }
}

// MARK: - Finished-lecture stats (weekly)

@MainActor
final class LectureListenStats: ObservableObject {
    static let shared = LectureListenStats()
    private let key = "beummati.lecture.finished.v1"

    struct Entry: Codable, Hashable {
        var seriesID: String
        var chapterID: String
        var finishedAt: Date
    }

    @Published private(set) var entries: [Entry] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        }
    }

    func recordFinished(seriesID: String, chapterID: String) {
        entries.append(Entry(seriesID: seriesID, chapterID: chapterID, finishedAt: Date()))
        // Keep last 200
        if entries.count > 200 { entries = Array(entries.suffix(200)) }
        persist()
    }

    var finishedThisWeek: Int {
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return entries.filter { $0.finishedAt >= weekAgo }.count
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
