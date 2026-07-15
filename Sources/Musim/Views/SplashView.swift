import SwiftUI
import AVFoundation
import AppKit

/// Splash: plays the brand logo-reveal video, then hands off to the app.
struct SplashView: View {
    var onFinished: () -> Void = {}
    @State private var player: AVQueuePlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                PlayerView(player: player)
                    .ignoresSafeArea()
            } else {
                // Fallback if the video is missing.
                MusimLogo(size: 96)
            }
        }
        .onAppear { start() }
    }

    private func start() {
        guard let url = Bundle.main.url(forResource: "splash", withExtension: "mp4") else {
            // No video bundled — brief pause then continue.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: onFinished)
            return
        }
        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = true
        player = queue
        queue.play()
        // Hand off when the reveal finishes (with a hard cap so we never hang).
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: item, queue: .main) { _ in onFinished() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: onFinished)
    }
}

/// The Musim mark, used in-app (sidebar, onboarding, about): the brand logo
/// image on a rounded tile, falling back to a glyph if the asset is absent.
struct MusimLogo: View {
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.black)
                .shadow(color: .black.opacity(0.25), radius: size * 0.1, y: size * 0.04)
            if let path = Bundle.main.url(forResource: "logo", withExtension: "png"),
               let img = NSImage(contentsOf: path) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
            } else {
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}
