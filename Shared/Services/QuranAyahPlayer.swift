import Foundation
import AVFoundation
import Combine

/// Ayah-by-ayah player (everyayah.com Arabic) with optional local Alafasy cache.
@MainActor
final class QuranAyahPlayer: ObservableObject {
    static let shared = QuranAyahPlayer()

    struct PlayState: Equatable {
        var surah: Int = 0
        var ayah: Int = 0
        var key: String = ""
        var playing: Bool = false
        var loading: Bool = false
        var error: String?
    }

    /// Default Mishary Alafasy folder on everyayah.com.
    static let alafasyFolder = "Alafasy_128kbps"
    private static let everyayahBase = "https://everyayah.com/data"

    @Published private(set) var state = PlayState()

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var ayahs: [QuranAyah] = []
    private var index = 0
    private var autoAdvance = true
    private var playGeneration = 0

    private init() {}

    static func arabicURL(surah: Int, ayah: Int, folder: String = alafasyFolder) -> URL? {
        let name = String(format: "%03d%03d", surah, ayah)
        return URL(string: "\(everyayahBase)/\(folder)/\(name).mp3")
    }

    func play(from ayah: QuranAyah, in siblings: [QuranAyah], autoAdvance: Bool = true) {
        LectureAudioSession.shared.pause()
        stop()
        self.ayahs = siblings
        self.autoAdvance = autoAdvance
        index = siblings.firstIndex(where: { $0.key == ayah.key }) ?? 0
        playCurrent()
    }

    func playSurah(_ siblings: [QuranAyah], startAyah: Int = 1, autoAdvance: Bool = true) {
        guard let start = siblings.first(where: { $0.numberInSurah == startAyah }) ?? siblings.first else { return }
        play(from: start, in: siblings, autoAdvance: autoAdvance)
    }

    func toggle() {
        guard let player else { return }
        if player.rate > 0 {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        player?.pause()
        state.playing = false
    }

    func resume() {
        LectureAudioSession.shared.pause()
        player?.play()
        state.playing = true
    }

    func stop() {
        playGeneration += 1
        clearEndObserver()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        ayahs = []
        index = 0
        state = PlayState()
    }

    private func playCurrent() {
        guard let ayah = ayahs[safe: index] else {
            stop()
            return
        }

        state = PlayState(
            surah: ayah.surah,
            ayah: ayah.numberInSurah,
            key: ayah.key,
            playing: false,
            loading: true
        )

        playGeneration += 1
        let generation = playGeneration
        let surah = ayah.surah
        let number = ayah.numberInSurah

        Task {
            let url: URL?
            if let local = await QuranAudioCache.shared.existingArabic(surah: surah, ayah: number) {
                url = local
            } else {
                url = Self.arabicURL(surah: surah, ayah: number)
            }
            guard generation == playGeneration else { return }
            guard let url else {
                state = PlayState(surah: surah, ayah: number, key: ayah.key, error: "Bad audio URL")
                return
            }
            startPlayback(url: url, ayah: ayah)
        }
    }

    private func startPlayback(url: URL, ayah: QuranAyah) {
        configureSession()
        clearEndObserver()

        let item = AVPlayerItem(url: url)
        let p = player ?? AVPlayer()
        player = p
        p.replaceCurrentItem(with: item)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onClipEnded()
            }
        }

        p.play()
        state.loading = false
        state.playing = true
        state.error = nil
        state.surah = ayah.surah
        state.ayah = ayah.numberInSurah
        state.key = ayah.key
    }

    private func onClipEnded() {
        guard autoAdvance else {
            state.playing = false
            return
        }
        index += 1
        if index >= ayahs.count {
            stop()
        } else {
            playCurrent()
        }
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }

    private func clearEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
