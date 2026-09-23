import SwiftUI

/// Persistent bottom bar while lecture audio continues after dismissing the full player.
struct MiniPlayerBar: View {
    @ObservedObject private var session = LectureAudioSession.shared

    var body: some View {
        if let np = session.nowPlaying, !session.showFullPlayer {
            VStack(spacing: 0) {
                // Thin progress
                GeometryReader { geo in
                    let p = session.duration > 0 ? min(1, max(0, session.currentTime / session.duration)) : 0
                    ZStack(alignment: .leading) {
                        Rectangle().fill(BeUmmatiTheme.ink.opacity(0.08))
                        Rectangle()
                            .fill(BeUmmatiTheme.teal)
                            .frame(width: geo.size.width * p)
                    }
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    Button {
                        session.showFullPlayer = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(BeUmmatiTheme.teal)
                                    .frame(width: 44, height: 44)
                                Image(systemName: np.seriesIcon)
                                    .foregroundStyle(.white)
                                    .font(.body.weight(.semibold))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(np.chapterTitle)
                                    .font(BeUmmatiTheme.ui(14, weight: .semibold))
                                    .foregroundStyle(BeUmmatiTheme.ink)
                                    .lineLimit(1)
                                Text(np.seriesTitle)
                                    .font(BeUmmatiTheme.ui(12))
                                    .foregroundStyle(BeUmmatiTheme.inkSecondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        session.togglePlay()
                    } label: {
                        Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(BeUmmatiTheme.teal)
                            .frame(width: 40, height: 40)
                    }

                    Button {
                        session.stopAndClear()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BeUmmatiTheme.inkSecondary)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .background(BeUmmatiTheme.parchment.opacity(0.92))
            .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
