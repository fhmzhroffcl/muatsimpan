import Foundation
import AppKit

// MARK: - Download models (mirrors VidBee's DownloadItem/DownloadStatus)

enum DownloadStatus: String, Codable {
    case pending, downloading, processing, completed, error, cancelled, paused
}

enum MediaType: String, Codable, CaseIterable, Identifiable {
    case video, audio
    var id: String { rawValue }
    var label: String { self == .video ? "Video" : "Audio" }
}

enum QualityPreset: String, Codable, CaseIterable, Identifiable {
    case best, good, normal, low
    var id: String { rawValue }
    var label: String {
        let my = AppSettings.shared.language == .malay
        switch self {
        case .best: return my ? "Terbaik" : "Best"
        case .good: return my ? "Bagus (1080p)" : "Good (1080p)"
        case .normal: return my ? "Biasa (720p)" : "Normal (720p)"
        case .low: return my ? "Rendah (480p)" : "Low (480p)"
        }
    }
    var videoSelector: String {
        switch self {
        case .best: return "bestvideo+bestaudio/best"
        case .good: return "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"
        case .normal: return "bestvideo[height<=720]+bestaudio/best[height<=720]/best"
        case .low: return "bestvideo[height<=480]+bestaudio/best[height<=480]/best"
        }
    }
}

enum ContainerOption: String, Codable, CaseIterable, Identifiable {
    case auto, mp4, mkv, webm, original
    var id: String { rawValue }
    var label: String {
        let my = AppSettings.shared.language == .malay
        switch self {
        case .auto: return "Auto (MP4/MKV)"
        case .original: return my ? "Asal" : "Original"
        default: return rawValue.uppercased()
        }
    }
}

struct DownloadProgressInfo: Codable, Equatable {
    var percent: Double = 0
    var speed: String?
    var eta: String?
    var downloaded: String?
    var total: String?
}

struct DownloadItem: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var url: String
    var title: String
    var thumbnailURL: String?
    var type: MediaType
    var status: DownloadStatus = .pending
    var progress: DownloadProgressInfo = DownloadProgressInfo()
    var errorMessage: String?
    var log: String = ""
    // metadata
    var duration: Double?
    var fileSize: Int64?
    var savedFilePath: String?
    var uploader: String?
    var channel: String?
    var descriptionText: String?
    var viewCount: Int?
    var platform: Platform = .generic
    // format chips
    var formatNote: String?      // e.g. 1080p
    var ext: String?             // e.g. mp4
    var audioFormat: String?     // e.g. m4a
    var quality: QualityPreset = .best
    var container: ContainerOption = .auto
    /// Explicit yt-dlp format selector chosen in the pre-download sheet
    /// (e.g. "bestvideo[height<=2160]+bestaudio"). Overrides `quality`.
    var formatSelector: String?
    /// Human label for the chosen quality chip (e.g. "4K", "8K", "Audio MP3").
    var qualityLabel: String?
    var estimatedSize: Int64?
    // timestamps
    var createdAt: Date = Date()
    var completedAt: Date?
}

// MARK: - Platform detection (like VidBee's link detection)

enum Platform: String, Codable, CaseIterable {
    case youtube, tiktok, instagram, twitter, facebook, bilibili, vimeo, twitch,
         soundcloud, reddit, dailymotion, generic

    var label: String {
        switch self {
        case .youtube: return "YouTube"
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram"
        case .twitter: return "X / Twitter"
        case .facebook: return "Facebook"
        case .bilibili: return "Bilibili"
        case .vimeo: return "Vimeo"
        case .twitch: return "Twitch"
        case .soundcloud: return "SoundCloud"
        case .reddit: return "Reddit"
        case .dailymotion: return "Dailymotion"
        case .generic: return "Web"
        }
    }

    var symbol: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .twitter: return "bird.fill"
        case .facebook: return "person.2.fill"
        case .bilibili: return "tv.fill"
        case .vimeo: return "v.circle.fill"
        case .twitch: return "gamecontroller.fill"
        case .soundcloud: return "waveform"
        case .reddit: return "bubble.left.and.bubble.right.fill"
        case .dailymotion: return "d.circle.fill"
        case .generic: return "globe"
        }
    }

    func folderName(for url: String? = nil) -> String {
        switch self {
        case .generic:
            guard let url,
                  let host = URL(string: url)?.host?.replacingOccurrences(of: "www.", with: ""),
                  !host.isEmpty else { return "Lain-lain" }
            let root = host.split(separator: ".").first.map(String.init) ?? host
            return root
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        default:
            return label.replacingOccurrences(of: " / Twitter", with: "")
        }
    }

    static func detect(from url: String) -> Platform {
        let u = url.lowercased()
        if u.contains("youtube.com") || u.contains("youtu.be") { return .youtube }
        if u.contains("tiktok.com") { return .tiktok }
        if u.contains("instagram.com") { return .instagram }
        if u.contains("twitter.com") || u.contains("x.com") { return .twitter }
        if u.contains("facebook.com") || u.contains("fb.watch") { return .facebook }
        if u.contains("bilibili.com") { return .bilibili }
        if u.contains("vimeo.com") { return .vimeo }
        if u.contains("twitch.tv") { return .twitch }
        if u.contains("soundcloud.com") { return .soundcloud }
        if u.contains("reddit.com") { return .reddit }
        if u.contains("dailymotion.com") { return .dailymotion }
        return .generic
    }

    /// Extract all http(s) links from arbitrary pasted text.
    static func extractLinks(from text: String) -> [String] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        var links: [String] = []
        detector?.enumerateMatches(in: text, range: range) { match, _, _ in
            if let url = match?.url, url.scheme == "http" || url.scheme == "https" {
                links.append(url.absoluteString)
            }
        }
        // de-dupe preserving order
        var seen = Set<String>()
        return links.filter { seen.insert($0).inserted }
    }
}

// MARK: - Library notes (sticky notes / tags on files & folders)

/// Dynamic sticky-note shapes, chosen by the user per note.
enum NoteSize: String, Codable, CaseIterable, Identifiable {
    case square, wide, big, tall
    var id: String { rawValue }
    var dims: CGSize {
        switch self {
        case .square: return CGSize(width: 128, height: 128)
        case .wide:   return CGSize(width: 190, height: 118)
        case .big:    return CGSize(width: 188, height: 188)
        case .tall:   return CGSize(width: 130, height: 206)
        }
    }
    var label: String {
        let my = AppSettings.shared.language == .malay
        switch self {
        case .square: return my ? "Segi empat sama" : "Square"
        case .wide:   return my ? "Melintang" : "Wide"
        case .big:    return my ? "Besar" : "Big"
        case .tall:   return my ? "Menegak" : "Tall"
        }
    }
    var symbol: String {
        switch self {
        case .square: return "square"
        case .wide:   return "rectangle"
        case .big:    return "square.fill"
        case .tall:   return "rectangle.portrait"
        }
    }
}

struct StickyNote: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var text: String = ""
    var color: String = "yellow" // yellow, pink, blue, green, orange, purple, teal
    var size: NoteSize = .square
    var rtf: Data? = nil          // optional rich text (bold/italic/underline/…)

    /// Rich attributed content if present, otherwise the plain text.
    var attributed: NSAttributedString {
        if let rtf, let s = try? NSAttributedString(
            data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            return s
        }
        return NSAttributedString(string: text)
    }
}

// MARK: - Supported sites list (top sites; full list via yt-dlp)

struct SupportedSite: Identifiable {
    let id = UUID()
    let name: String
    let domain: String
    let symbol: String
    var logo: String? = nil   // bundled official logo (logos/<name>.png)

    /// Official logo image, if bundled.
    var logoImage: NSImage? {
        guard let logo,
              let url = Bundle.main.url(forResource: logo, withExtension: "png", subdirectory: "logos")
                ?? Bundle.main.url(forResource: logo, withExtension: "png")
        else { return nil }
        return NSImage(contentsOf: url)
    }

    static let featured: [SupportedSite] = [
        .init(name: "YouTube", domain: "youtube.com", symbol: "play.rectangle.fill", logo: "youtube"),
        .init(name: "TikTok", domain: "tiktok.com", symbol: "music.note", logo: "tiktok"),
        .init(name: "Instagram", domain: "instagram.com", symbol: "camera.fill", logo: "instagram"),
        .init(name: "X / Twitter", domain: "x.com", symbol: "bird.fill", logo: "x"),
        .init(name: "Facebook", domain: "facebook.com", symbol: "person.2.fill", logo: "facebook"),
        .init(name: "Vimeo", domain: "vimeo.com", symbol: "v.circle.fill", logo: "vimeo"),
        .init(name: "Twitch", domain: "twitch.tv", symbol: "gamecontroller.fill", logo: "twitch"),
        .init(name: "SoundCloud", domain: "soundcloud.com", symbol: "waveform", logo: "soundcloud"),
        .init(name: "Bilibili", domain: "bilibili.com", symbol: "tv.fill", logo: "bilibili"),
        .init(name: "Reddit", domain: "reddit.com", symbol: "bubble.left.and.bubble.right.fill", logo: "reddit"),
        .init(name: "Dailymotion", domain: "dailymotion.com", symbol: "d.circle.fill"),
        .init(name: "Bandcamp", domain: "bandcamp.com", symbol: "music.quarternote.3"),
        .init(name: "Rumble", domain: "rumble.com", symbol: "r.circle.fill"),
        .init(name: "Odysee", domain: "odysee.com", symbol: "o.circle.fill"),
        .init(name: "Pinterest", domain: "pinterest.com", symbol: "pin.fill"),
        .init(name: "LinkedIn", domain: "linkedin.com", symbol: "briefcase.fill"),
        .init(name: "Tumblr", domain: "tumblr.com", symbol: "t.circle.fill"),
        .init(name: "VK", domain: "vk.com", symbol: "v.square.fill"),
        .init(name: "Niconico", domain: "nicovideo.jp", symbol: "n.circle.fill"),
        .init(name: "Streamable", domain: "streamable.com", symbol: "s.circle.fill"),
    ]
}
