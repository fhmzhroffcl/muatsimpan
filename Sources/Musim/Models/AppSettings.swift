import Foundation
import Combine
import CoreServices

/// How often the download-history report is written to a text file.
enum HistoryLogFrequency: String, CaseIterable, Identifiable {
    case never, daily, weekly, monthly
    var id: String { rawValue }
    var label: String {
        let my = AppSettings.shared.language == .malay
        switch self {
        case .never:   return my ? "Jangan simpan fail" : "Don’t save a file"
        case .daily:   return my ? "Harian" : "Daily"
        case .weekly:  return my ? "Mingguan" : "Weekly"
        case .monthly: return my ? "Bulanan" : "Monthly"
        }
    }
}

/// Persistent app settings — mirrors VidBee's AppSettings, backed by UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let d = UserDefaults.standard
    private static let cleanReleaseStateKey = "cleanReleaseStateVersion"
    private static let cleanReleaseStateVersion = "2026-07-15-player-editor-v2"
    static let defaultPlatformFolders = ["YouTube", "TikTok", "Facebook", "Instagram"]
    private static let personalDefaultsKeys = [
        "onboardingCompleted",
        "userName",
        "downloadPath",
        "maxConcurrentDownloads",
        "browserForCookies",
        "proxy",
        "filenameTemplate",
        "autoNaming",
        "oneClickType",
        "oneClickQuality",
        "container",
        "embedSubs",
        "embedThumbnail",
        "embedMetadata",
        "embedChapters",
        "notifyOnComplete",
        "channelSubfolders",
        "organizeByPlatform",
        "language",
        "appearance",
        "accent",
        "pattern",
        "autoUpdateEngine",
        "historyLog",
        "advancedNaming",
        "namePrefix",
        "nameSuffix",
        "nameSeparator",
        "nameDate",
        "nameCounter",
        "cookieResetV3"
    ]

    @Published var onboardingCompleted: Bool { didSet { d.set(onboardingCompleted, forKey: "onboardingCompleted") } }
    @Published var userName: String { didSet { d.set(userName, forKey: "userName") } }
    @Published var downloadPath: String { didSet { d.set(downloadPath, forKey: "downloadPath") } }
    @Published var maxConcurrentDownloads: Int { didSet { d.set(maxConcurrentDownloads, forKey: "maxConcurrentDownloads") } }
    @Published var browserForCookies: String { didSet { d.set(browserForCookies, forKey: "browserForCookies") } }
    @Published var proxy: String { didSet { d.set(proxy, forKey: "proxy") } }
    @Published var filenameTemplate: String { didSet { d.set(filenameTemplate, forKey: "filenameTemplate") } }
    @Published var autoNaming: Bool { didSet { d.set(autoNaming, forKey: "autoNaming") } }
    @Published var oneClickType: MediaType { didSet { d.set(oneClickType.rawValue, forKey: "oneClickType") } }
    @Published var oneClickQuality: QualityPreset { didSet { d.set(oneClickQuality.rawValue, forKey: "oneClickQuality") } }
    @Published var container: ContainerOption { didSet { d.set(container.rawValue, forKey: "container") } }
    @Published var embedSubs: Bool { didSet { d.set(embedSubs, forKey: "embedSubs") } }
    @Published var embedThumbnail: Bool { didSet { d.set(embedThumbnail, forKey: "embedThumbnail") } }
    @Published var embedMetadata: Bool { didSet { d.set(embedMetadata, forKey: "embedMetadata") } }
    @Published var embedChapters: Bool { didSet { d.set(embedChapters, forKey: "embedChapters") } }
    @Published var notifyOnComplete: Bool { didSet { d.set(notifyOnComplete, forKey: "notifyOnComplete") } }
    @Published var channelSubfolders: Bool { didSet { d.set(channelSubfolders, forKey: "channelSubfolders") } }
    @Published var organizeByPlatform: Bool { didSet { d.set(organizeByPlatform, forKey: "organizeByPlatform") } }
    @Published var language: AppLanguage { didSet { d.set(language.rawValue, forKey: "language") } }
    @Published var appearance: AppAppearance { didSet { d.set(appearance.rawValue, forKey: "appearance") } }
    @Published var accent: String { didSet { d.set(accent, forKey: "accent") } }
    @Published var pattern: String { didSet { d.set(pattern, forKey: "pattern") } }
    @Published var autoUpdateEngine: Bool { didSet { d.set(autoUpdateEngine, forKey: "autoUpdateEngine") } }
    @Published var historyLog: HistoryLogFrequency { didSet { d.set(historyLog.rawValue, forKey: "historyLog") } }
    // Advanced naming (prefix/suffix/separator/date/counter → yt-dlp template)
    @Published var advancedNaming: Bool { didSet { d.set(advancedNaming, forKey: "advancedNaming") } }
    @Published var namePrefix: String { didSet { d.set(namePrefix, forKey: "namePrefix") } }
    @Published var nameSuffix: String { didSet { d.set(nameSuffix, forKey: "nameSuffix") } }
    @Published var nameSeparator: String { didSet { d.set(nameSeparator, forKey: "nameSeparator") } }
    @Published var nameDate: String { didSet { d.set(nameDate, forKey: "nameDate") } }      // none | %Y%m%d | %Y-%m-%d
    @Published var nameCounter: Bool { didSet { d.set(nameCounter, forKey: "nameCounter") } }

    static let browsers = ["none", "auto", "safari", "chrome", "firefox", "edge", "brave", "opera", "vivaldi"]

    /// Actual browser to read cookies from ("auto" resolves to the default).
    var resolvedCookieBrowser: String {
        browserForCookies == "auto" ? Self.defaultBrowser() : browserForCookies
    }
    var usesCookies: Bool { browserForCookies != "none" }
    static let defaultTemplate = "%(title)s.%(ext)s"

    private init() {
        Self.prepareCleanSharedReleaseIfNeeded(d)
        onboardingCompleted = d.bool(forKey: "onboardingCompleted")
        userName = d.string(forKey: "userName") ?? ""
        let defaultDownloads = Self.defaultDownloadPath()
        downloadPath = d.string(forKey: "downloadPath") ?? defaultDownloads
        let mc = d.integer(forKey: "maxConcurrentDownloads")
        maxConcurrentDownloads = mc == 0 ? 3 : mc
        browserForCookies = d.string(forKey: "browserForCookies") ?? "none"
        proxy = d.string(forKey: "proxy") ?? ""
        filenameTemplate = d.string(forKey: "filenameTemplate") ?? Self.defaultTemplate
        autoNaming = d.object(forKey: "autoNaming") == nil ? true : d.bool(forKey: "autoNaming")
        oneClickType = MediaType(rawValue: d.string(forKey: "oneClickType") ?? "") ?? .video
        oneClickQuality = QualityPreset(rawValue: d.string(forKey: "oneClickQuality") ?? "") ?? .best
        container = ContainerOption(rawValue: d.string(forKey: "container") ?? "") ?? .auto
        embedSubs = d.bool(forKey: "embedSubs")
        embedThumbnail = d.object(forKey: "embedThumbnail") == nil ? true : d.bool(forKey: "embedThumbnail")
        embedMetadata = d.object(forKey: "embedMetadata") == nil ? true : d.bool(forKey: "embedMetadata")
        embedChapters = d.bool(forKey: "embedChapters")
        notifyOnComplete = d.object(forKey: "notifyOnComplete") == nil ? true : d.bool(forKey: "notifyOnComplete")
        channelSubfolders = d.bool(forKey: "channelSubfolders")
        organizeByPlatform = d.object(forKey: "organizeByPlatform") == nil ? true : d.bool(forKey: "organizeByPlatform")
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .malay
        appearance = AppAppearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .dark
        accent = d.string(forKey: "accent") ?? "sunset"
        pattern = d.string(forKey: "pattern") ?? "batik"
        autoUpdateEngine = d.object(forKey: "autoUpdateEngine") == nil ? true : d.bool(forKey: "autoUpdateEngine")
        historyLog = HistoryLogFrequency(rawValue: d.string(forKey: "historyLog") ?? "") ?? .weekly
        advancedNaming = d.bool(forKey: "advancedNaming")
        namePrefix = d.string(forKey: "namePrefix") ?? ""
        nameSuffix = d.string(forKey: "nameSuffix") ?? ""
        nameSeparator = d.string(forKey: "nameSeparator") ?? " - "
        nameDate = d.string(forKey: "nameDate") ?? "none"
        nameCounter = d.bool(forKey: "nameCounter")

        // Migration: browser-cookie extraction triggers a macOS Keychain prompt
        // and (for YouTube) forces JS-challenge formats, which broke downloads.
        // Reset to "none" so the app works out of the box; cookies stay an
        // explicit opt-in in Settings for login-required sites.
        if !d.bool(forKey: "cookieResetV3") {
            browserForCookies = "none"
            d.set(true, forKey: "cookieResetV3")
        }
    }

    private static func defaultDownloadPath() -> String {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Musim").path
    }

    /// This share build should open like a fresh install, even on a Mac that
    /// previously ran development builds with personal name/history/settings.
    /// Downloaded media files are intentionally left untouched.
    private static func prepareCleanSharedReleaseIfNeeded(_ d: UserDefaults) {
        guard d.string(forKey: cleanReleaseStateKey) != cleanReleaseStateVersion else { return }

        for key in personalDefaultsKeys {
            d.removeObject(forKey: key)
        }
        clearPrivateAppState()
        d.set(cleanReleaseStateVersion, forKey: cleanReleaseStateKey)
        d.synchronize()
    }

    private static func clearPrivateAppState() {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Musim", isDirectory: true) else { return }
        let privateItems = ["history.json", "notes.json", "positions.json", "Report", "Laporan"]
        for item in privateItems {
            try? fm.removeItem(at: support.appendingPathComponent(item))
        }
    }

    /// The user's default web browser, mapped to a yt-dlp cookie source.
    static func defaultBrowser() -> String {
        guard let handler = LSCopyDefaultHandlerForURLScheme("http" as CFString)?.takeRetainedValue() as String? else {
            return "safari"
        }
        let id = handler.lowercased()
        if id.contains("chrome") { return "chrome" }
        if id.contains("firefox") { return "firefox" }
        if id.contains("edgemac") || id.contains("edge") { return "edge" }
        if id.contains("brave") { return "brave" }
        if id.contains("opera") { return "opera" }
        if id.contains("vivaldi") { return "vivaldi" }
        return "safari"
    }

    func ensureDownloadDirectory() {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: downloadPath, withIntermediateDirectories: true)
        for folder in Self.defaultPlatformFolders {
            let url = URL(fileURLWithPath: downloadPath).appendingPathComponent(folder, isDirectory: true)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// The yt-dlp output template actually used for downloads.
    func effectiveTemplate() -> String {
        guard autoNaming else { return "%(id)s.%(ext)s" }
        guard advancedNaming else { return filenameTemplate }
        var parts: [String] = []
        if !namePrefix.isEmpty { parts.append(namePrefix) }
        parts.append("%(title)s")
        if nameDate != "none" { parts.append("%(upload_date>\(nameDate))s") }
        if nameCounter { parts.append("%(autonumber)03d") }
        if !nameSuffix.isEmpty { parts.append(nameSuffix) }
        return parts.joined(separator: nameSeparator) + ".%(ext)s"
    }

    /// A friendly preview of the composed filename for the settings UI.
    func namingExample() -> String {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = nameDate == "%Y-%m-%d" ? "yyyy-MM-dd" : "yyyyMMdd"
        var parts: [String] = []
        if !namePrefix.isEmpty { parts.append(namePrefix) }
        parts.append("Video Title")
        if nameDate != "none" { parts.append(df.string(from: Date())) }
        if nameCounter { parts.append("001") }
        if !nameSuffix.isEmpty { parts.append(nameSuffix) }
        return parts.joined(separator: nameSeparator) + ".mp4"
    }
}
