import SwiftUI
import AVFoundation
import AppKit

/// A lightweight video surface backed by AVPlayerLayer.
///
/// We deliberately avoid SwiftUI's `VideoPlayer` / AVKit's `AVPlayerView`,
/// which fails to load (Obj-C class demangling error) in this SwiftPM-built
/// bundle. AVPlayerLayer is Core Animation and always available.
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer
    var showsControls: Bool = false

    func makeNSView(context: Context) -> PlayerHostView {
        let v = PlayerHostView()
        v.attach(player)
        return v
    }

    func updateNSView(_ nsView: PlayerHostView, context: Context) {
        nsView.attach(player)
    }
}

final class PlayerHostView: NSView {
    private let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
        layer?.backgroundColor = NSColor.black.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func attach(_ player: AVPlayer) {
        if playerLayer.player !== player { playerLayer.player = player }
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
