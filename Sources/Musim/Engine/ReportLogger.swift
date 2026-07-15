import Foundation

/// Appends a line per completed download to a rolling text report inside the
/// app's support folder (`Report/`), so the user can look back at what they
/// grabbed and from where. Frequency is controlled by the `historyLog` setting;
/// `.never` keeps history in-app only (no file is written).
@MainActor
final class ReportLogger {
    static let shared = ReportLogger()
    private init() {}

    /// Folder is "Laporan" when the app language is Malay, else "Report".
    var reportDir: URL {
        let name = AppSettings.shared.language == .malay ? "Laporan" : "Report"
        return YtDlpManager.shared.supportDir.appendingPathComponent(name)
    }

    /// Log a finished download. No-op when the setting is `.never`.
    func log(_ item: DownloadItem) {
        let freq = AppSettings.shared.historyLog
        guard freq != .never else { return }

        let now = Date()
        let stamp = Self.iso.string(from: now)
        let platform = item.platform.label
        let kind = item.type == .video ? "Video" : "Audio"
        let path = item.savedFilePath ?? "-"
        let line = "\(stamp)\t\(kind)\t\(platform)\t\(item.title)\t\(item.url)\t\(path)\n"

        let url = reportDir.appendingPathComponent(fileName(for: freq, date: now))
        try? FileManager.default.createDirectory(at: reportDir, withIntermediateDirectories: true)

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) { handle.write(data) }
        } else {
            // New file — write a header first.
            let header = AppSettings.shared.language == .malay
                ? "Musim — Laporan arkib (\(freq.rawValue))\nMasa\tJenis\tPlatform\tTajuk\tPautan\tDisimpan di\n"
                : "Musim — Archive report (\(freq.rawValue))\nWhen\tType\tPlatform\tTitle\tLink\tSaved to\n"
            try? (header + line).write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func fileName(for freq: HistoryLogFrequency, date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        switch freq {
        case .daily:   f.dateFormat = "yyyy-MM-dd"
        case .weekly:  f.dateFormat = "yyyy-'W'ww"
        case .monthly: f.dateFormat = "yyyy-MM"
        case .never:   f.dateFormat = "yyyy-MM-dd"
        }
        return "musim-\(f.string(from: date)).txt"
    }

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()
}
