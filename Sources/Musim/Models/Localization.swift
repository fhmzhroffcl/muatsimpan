import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case malay, english
    var id: String { rawValue }
    var label: String { self == .malay ? "Bahasa Melayu" : "English" }
    var short: String { self == .malay ? "BM" : "EN" }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        let my = AppSettings.shared.language == .malay
        switch self {
        case .system: return my ? "Ikut Sistem" : "System"
        case .light: return my ? "Cerah" : "Light"
        case .dark: return my ? "Gelap" : "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Minimal string table. `L.t("key")` returns the string for the active
/// language. Falls back to the key itself if missing.
enum L {
    static func t(_ key: String) -> String {
        let lang = AppSettings.shared.language
        return (table[key]?[lang]) ?? table[key]?[.english] ?? key
    }

    private static let table: [String: [AppLanguage: String]] = [
        // Sidebar
        "nav.archive": [.malay: "Arkib", .english: "Archive"],
        "nav.library": [.malay: "Pustaka", .english: "Library"],
        "nav.guide": [.malay: "Panduan", .english: "Guide"],
        "nav.download": [.malay: "Arkib", .english: "Archive"],
        "nav.howto": [.malay: "Panduan", .english: "Guide"],
        "nav.sites": [.malay: "Panduan", .english: "Guide"],
        "nav.settings": [.malay: "Tetapan", .english: "Settings"],
        "nav.about": [.malay: "Perihal", .english: "About"],
        // Download page
        "dl.placeholder": [.malay: "Tampal satu atau banyak pautan video/audio…", .english: "Paste one or many video/audio links…"],
        "dl.fetchingFrom": [.malay: "Menyemak daripada", .english: "Checking from"],
        "dl.fetch": [.malay: "Simpan", .english: "Save"],
        "dl.paste": [.malay: "Tampal", .english: "Paste"],
        "dl.download": [.malay: "Simpan ke arkib", .english: "Save to archive"],
        "dl.downloadAll": [.malay: "Simpan Semua", .english: "Save All"],
        "dl.readmore": [.malay: "Baca lagi", .english: "Read more"],
        "dl.readless": [.malay: "Tutup", .english: "Show less"],
        "dl.reading": [.malay: "Membaca maklumat video…", .english: "Reading video info…"],
        "dl.recent": [.malay: "Baru diarkibkan", .english: "Recently archived"],
        "dl.downloading": [.malay: "Sedang menyimpan", .english: "Saving"],
        "dl.ready": [.malay: "Sedia disimpan", .english: "Ready to save"],
        "dl.subtitle": [.malay: "Tampal pautan, pilih, dan simpan ke arkib.",
                        .english: "Paste a link, choose your format, and save it to your archive."],
        // Common
        "common.video": [.malay: "Video", .english: "Video"],
        "common.audio": [.malay: "Audio", .english: "Audio"],
        "common.quality": [.malay: "Kualiti", .english: "Quality"],
        "common.format": [.malay: "Format", .english: "Format"],
        "common.clear": [.malay: "Kosongkan", .english: "Clear"],
        "common.best": [.malay: "Terbaik", .english: "Best"],
        "common.play": [.malay: "Main", .english: "Play"],
        "common.reveal": [.malay: "Tunjuk di Finder", .english: "Reveal in Finder"],
        "common.openLibrary": [.malay: "Buka di Pustaka", .english: "Open in Library"],
        "common.retry": [.malay: "Cuba Semula", .english: "Retry"],
        "common.loading": [.malay: "Memuat…", .english: "Loading…"],
        "common.saved": [.malay: "Disimpan", .english: "Saved"],
        "common.failed": [.malay: "Gagal", .english: "Failed"],
        "common.queued": [.malay: "Dalam giliran…", .english: "Queued…"],
        "common.finishing": [.malay: "Menyiapkan…", .english: "Finishing…"],
        // Activity
        "activity.title": [.malay: "Aktiviti", .english: "Activity"],
        "activity.active": [.malay: "Aktif", .english: "Active"],
        "activity.history": [.malay: "Sejarah", .english: "History"],
        "activity.empty": [.malay: "Tiada simpanan aktif", .english: "No active saves"],
        "act.playInApp": [.malay: "Main dalam app", .english: "Play in app"],
        "act.edit": [.malay: "Sunting video", .english: "Edit video"],
        "act.reveal": [.malay: "Cari di Finder", .english: "Find in Finder"],
        "act.remove": [.malay: "Buang dari sejarah", .english: "Remove from history"],
        "act.retry": [.malay: "Cuba semula", .english: "Retry"],
        "act.clearHistory": [.malay: "Kosongkan sejarah", .english: "Clear history"],
        "act.clearNotice": [.malay: "Sejarah dalam app akan dikosongkan. Fail teks laporan dalam folder Laporan kekal tersimpan.",
                            .english: "In-app history will be cleared. The report text files in the Report folder are kept."],
        "common.cancel": [.malay: "Batal", .english: "Cancel"],
        // Library
        "lib.folders": [.malay: "Folder", .english: "Folders"],
        "lib.media": [.malay: "Media", .english: "Media"],
        "lib.player": [.malay: "Pemain", .english: "Player"],
        "lib.editor": [.malay: "Editor", .english: "Editor"],
        "lib.search": [.malay: "Cari tajuk, platform, kata kunci…", .english: "Search titles, platforms, keywords…"],
        "lib.newFolder": [.malay: "Folder Baharu", .english: "New Folder"],
        "lib.selectAll": [.malay: "Pilih Semua", .english: "Select All"],
        "lib.all": [.malay: "Semua", .english: "All"],
        "lib.videos": [.malay: "Video", .english: "Videos"],
        "lib.notes": [.malay: "Nota", .english: "Notes"],
        "lib.allNotes": [.malay: "Semua nota", .english: "All notes"],
    ]
}

/// Convenience wrapper so views can write `Text(loc("key"))`.
func loc(_ key: String) -> String { L.t(key) }
