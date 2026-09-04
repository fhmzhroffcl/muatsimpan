import AppKit

/// Lightweight UI sound effects. Plays short clips bundled in Resources/sfx,
/// gated by the user's `sfxEnabled` setting. A missing file is a silent no-op,
/// so the app runs fine even before a sound pack is installed.
final class SoundFX {
    static let shared = SoundFX()

    enum Cue: String, CaseIterable {
        case tap, toggle, save, complete, error
    }

    private var cache: [String: NSSound] = [:]

    func play(_ cue: Cue) {
        guard AppSettings.shared.sfxEnabled else { return }
        guard let sound = sound(for: cue.rawValue) else { return }
        sound.stop()
        sound.play()
    }

    private func sound(for name: String) -> NSSound? {
        if let s = cache[name] { return s }
        for ext in ["wav", "aiff", "m4a", "mp3"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "sfx"),
               let s = NSSound(contentsOf: url, byReference: false) {
                s.volume = 0.35
                cache[name] = s
                return s
            }
        }
        return nil
    }
}
