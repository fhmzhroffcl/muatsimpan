import Foundation
import SwiftUI

/// Rotating greetings that follow the app language. Malay mode mixes proper
/// Bahasa Melayu with everyday Manglish; English mode is Malaysian-casual.
/// Format: "<salam>, <name>. <line>" — the name is always present, no emoji.
@MainActor
final class GreetingEngine: ObservableObject {
    static let shared = GreetingEngine()

    @Published var current: String = ""
    private var timer: Timer?

    private init() {
        current = build()
        timer = Timer.scheduledTimer(withTimeInterval: 150, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.rotate() }
        }
    }

    private var name: String {
        let n = AppSettings.shared.userName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? (AppSettings.shared.language == .malay ? "bos" : "there") : n
    }

    func rotate() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { current = build() }
    }

    /// Called when language changes so the greeting updates immediately.
    func refresh() { current = build() }

    private func build() -> String {
        let malay = AppSettings.shared.language == .malay
        let salam = (malay ? Self.salamsMY : Self.salamsEN).randomElement()!
        let line = (malay ? Self.linesMY : Self.linesEN).randomElement()!
        return "\(salam), \(name). \(line)"
    }

    // MARK: Salutations

    private static let salamsMY = [
        "Hai", "Selamat pagi", "Apa khabar", "Salam", "Semekom", "Assalamualaikum",
        "Hello", "Wei", "Yo", "Eh"
    ]
    private static let salamsEN = [
        "Hi", "Hey", "Hello", "Yo", "Morning", "Sup", "Oi"
    ]

    // MARK: Malay / Manglish lines

    private static let linesMY = [
        "Nak arkib apa hari ni?",
        "Nak arkib apa tu?",
        "Nak simpan video mana hari ni?",
        "Haaa, donlod apa?",
        "Apa nak curi hari ni? Curi ilmu je tau.",
        "Ada video best nak simpan?",
        "Jom simpan, jom arkib.",
        "Tampal je pautan tu, biar Musim uruskan.",
        "Nak video ke audio hari ni?",
        "Banyak mana nak simpan hari ni?",
        "Video viral tu jangan lupa simpan.",
        "Playlist dah backup ke belum?",
        "Sekali tampal, terus jadi.",
        "Ada lagu baru nak simpan?",
        "Koleksi video tak akan penuh sendiri tau.",
        "Apa cerita, lama tak arkib?",
        "Simpan dulu, tonton kemudian.",
        "On je, kita gas sampai 8K.",
        "Jom kemas pustaka video sikit.",
        "Content creator kegemaran dah upload baru tu.",
        "Nak arkib video sebelum ia hilang?",
        "Rehat sekejap, biar Musim yang kerja.",
        "Video panjang pun kacang je.",
        "Steady, tampal je pautan.",
        "Jangan segan, banyak pautan pun boleh.",
        "Backup itu tanda sayang.",
        "Satu hari satu video, sihat jiwa.",
        "Nak simpan reels ke shorts hari ni?",
        "Wei, ada video best tak nak kongsi kat sini?",
        "Percaya proses je — tampal, pilih, simpan.",
    ]

    // MARK: English (Malaysian casual) lines

    private static let linesEN = [
        "What are you archiving today?",
        "What are we saving today?",
        "Got a video to keep?",
        "Paste a link, I'll handle the rest.",
        "Video or audio today?",
        "How many are we grabbing today?",
        "That viral clip won't save itself.",
        "Backed up your playlist yet?",
        "One paste and it's done.",
        "New track to save?",
        "Your collection won't fill itself, you know.",
        "Long time no archive — what's good?",
        "Save now, watch later.",
        "Let's push it all the way to 8K.",
        "Time to tidy up the library a bit?",
        "Your favourite creator just posted.",
        "Archive it before it disappears.",
        "Take a break, let Musim do the work.",
        "Three-hour video? Easy.",
        "Steady lah, just paste the link.",
        "Don't be shy, multiple links work too.",
        "Backing up is caring.",
        "One video a day keeps the FOMO away.",
        "Saving a reel or a short today?",
        "Got a good clip to share here?",
        "Trust the process — paste, pick, save.",
    ]
}
