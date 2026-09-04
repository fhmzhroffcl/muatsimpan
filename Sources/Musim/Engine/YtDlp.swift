import Foundation

/// Manages the yt-dlp (and ffmpeg) binaries. yt-dlp ships inside the app bundle
/// so downloads work offline on first launch, but a self-updating copy is kept
/// in Application Support and always takes priority — the bundled binary goes
/// stale as sites rotate their streaming (a two-month-old build starts hitting
/// HTTP 403 on video streams), so Musim quietly pulls the latest release in the
/// background and self-heals a failed download by refreshing on the spot.
final class YtDlpManager: ObservableObject {
    static let shared = YtDlpManager()

    @Published var isReady = false
    @Published var isInstalling = false
    @Published var installProgress: Double = 0
    @Published var installError: String?
    @Published var isUpdatingEngine = false
    @Published var engineVersion: String?

    let supportDir: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Musim", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// yt-dlp release feed. The macOS build is a single self-contained binary.
    private let latestAPI = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!
    private let macBinaryURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
    private let lastCheckKey = "musim.ytdlp.lastUpdateCheck"

    /// The writable, auto-updated copy that overrides the bundled one.
    private var managedBinary: URL { supportDir.appendingPathComponent("yt-dlp") }

    /// The auto-updated copy wins; the bundled binary is the offline fallback,
    /// then any Homebrew/system install.
    var binaryPath: String? {
        var candidates: [String] = [managedBinary.path]
        if let res = Bundle.main.resourcePath { candidates.append(res + "/yt-dlp") }
        candidates += [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    var ffmpegPath: String? {
        var candidates: [String] = []
        if let res = Bundle.main.resourcePath { candidates.append(res + "/ffmpeg") }
        candidates += [
            supportDir.appendingPathComponent("ffmpeg").path,
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Bundled Deno JS runtime — lets yt-dlp solve YouTube's JS "n-challenge"
    /// (required for logged-in / cookie-based formats), matching VidBee.
    var denoPath: String? {
        var candidates: [String] = []
        if let res = Bundle.main.resourcePath { candidates.append(res + "/deno") }
        candidates += ["/opt/homebrew/bin/deno", "/usr/local/bin/deno"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// `--js-runtimes deno:<path>` args when Deno is available.
    var jsRuntimeArgs: [String] {
        guard let deno = denoPath else { return [] }
        return ["--js-runtimes", "deno:\(deno)"]
    }

    func checkOrInstall() {
        if binaryPath != nil {
            isReady = true
        } else {
            Task { await install() }
        }
        updateEngineIfNeeded()
    }

    /// First-run fallback when no binary is present anywhere.
    func install() async {
        await MainActor.run { isInstalling = true; installError = nil }
        let ok = await downloadManagedBinary()
        await MainActor.run {
            isInstalling = false
            if ok {
                isReady = true
                installProgress = 1
            } else {
                installError = AppSettings.shared.language == .malay
                    ? "Simpanan alat media gagal (ralat HTTP)"
                    : "Engine download failed (HTTP error)"
            }
        }
    }

    // MARK: - Engine auto-update

    /// Background check (throttled to once per day): if yt-dlp's "latest" release
    /// tag has moved past the binary in use, quietly download the new one into
    /// Application Support so `binaryPath` picks it up. Any failure is silent and
    /// leaves the current binary in place.
    func updateEngineIfNeeded(force: Bool = false) {
        // Respect the user's "Auto-update engine" toggle for the scheduled check.
        // (Self-heal via refreshEngineNow() stays available so a failed download
        // can always recover.)
        if !force && !AppSettings.shared.autoUpdateEngine { return }
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let defaults = UserDefaults.standard
            if !force,
               let last = defaults.object(forKey: self.lastCheckKey) as? Date,
               Date().timeIntervalSince(last) < 86_400 { return }
            guard let latest = await self.latestTag() else { return }
            defaults.set(Date(), forKey: self.lastCheckKey)
            let current = self.currentVersion()
            await MainActor.run { self.engineVersion = current }
            // Already on the latest tag — nothing to do (bundled or managed).
            if current == latest { return }
            _ = await self.downloadManagedBinary()
        }
    }

    /// Force an immediate refresh — used to self-heal a download that failed on a
    /// stale engine. Returns true when a fresh binary was installed.
    @discardableResult
    func refreshEngineNow() async -> Bool {
        await downloadManagedBinary()
    }

    /// The latest yt-dlp release tag (e.g. "2026.08.19"), or nil on any error.
    private func latestTag() async -> String? {
        var req = URLRequest(url: latestAPI)
        req.setValue("Musim", forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return nil }
        return tag
    }

    /// `yt-dlp --version` of whichever binary `binaryPath` currently resolves.
    private func currentVersion() -> String? {
        guard let bin = binaryPath else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["--version"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Download the latest macOS yt-dlp into Application Support and make it
    /// runnable. Serialized by `isUpdatingEngine` so overlapping triggers coalesce.
    @discardableResult
    private func downloadManagedBinary() async -> Bool {
        if await MainActor.run(body: { self.isUpdatingEngine }) { return false }
        await MainActor.run { self.isUpdatingEngine = true }
        defer { Task { @MainActor in self.isUpdatingEngine = false } }
        do {
            let (tmp, response) = try await URLSession.shared.download(from: macBinaryURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            let dest = managedBinary
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
            // clear quarantine so it runs without a Gatekeeper prompt
            let x = Process()
            x.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            x.arguments = ["-d", "com.apple.quarantine", dest.path]
            try? x.run(); x.waitUntilExit()
            await MainActor.run {
                self.isReady = true
                self.engineVersion = self.currentVersion()
            }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Media probe (full metadata + formats for pre-download options)

struct ProbedFormat: Identifiable, Equatable {
    var id: String          // format_id
    var height: Int?
    var ext: String
    var vcodec: String?
    var acodec: String?
    var filesize: Int64?
    var note: String?
    var fps: Double?
    var isVideo: Bool { (vcodec ?? "none") != "none" }
    var isAudioOnly: Bool { !isVideo && (acodec ?? "none") != "none" }
}

struct MediaProbe {
    var title: String
    var thumbnail: String?
    var description: String?
    var uploader: String?
    var channel: String?
    var duration: Double?
    var viewCount: Int?
    var formats: [ProbedFormat]

    /// Distinct video heights available, descending (8K first if present).
    var heights: [Int] {
        Array(Set(formats.compactMap { $0.isVideo ? $0.height : nil })).sorted(by: >)
    }

    /// Best-effort size estimate for a chosen height: largest video stream at
    /// that height + largest audio-only stream.
    func estimatedSize(height: Int?) -> Int64? {
        let audio = formats.filter(\.isAudioOnly).compactMap(\.filesize).max() ?? 0
        if let height {
            let video = formats.filter { $0.isVideo && $0.height == height }.compactMap(\.filesize).max()
            guard let video else { return nil }
            return video + audio
        }
        return audio > 0 ? audio : nil
    }

    static func heightLabel(_ h: Int) -> String {
        switch h {
        case 4320...: return "8K"
        case 2160..<4320: return "4K"
        case 1440..<2160: return "2K"
        default: return "\(h)p"
        }
    }
}

/// Lightweight error carrying a user-facing message.
struct ProbeError: Error { let message: String }

/// Turns raw yt-dlp stderr into a short, actionable message.
func friendlyError(from stderr: String) -> String {
    let lower = stderr.lowercased()
    let my = AppSettings.shared.language == .malay
    if lower.contains("log in") || lower.contains("logged-in") || lower.contains("login required") ||
        lower.contains("sign in") || lower.contains("private") || lower.contains("cookies") {
        return my ? "Pautan ini perlukan log masuk. Hidupkan kuki pelayar dalam Tetapan, kemudian cuba lagi."
                  : "This post needs a login. Turn on browser cookies in Settings, then try again."
    }
    if lower.contains("removed by the uploader") || lower.contains("has been removed") {
        return my ? "Video ini telah dibuang oleh pemuat naiknya — ia tiada lagi di sumber."
                  : "This video was removed by its uploader — it no longer exists at the source."
    }
    if lower.contains("members-only") || lower.contains("join this channel") || lower.contains("music premium") {
        return my ? "Video ini untuk ahli/langganan sahaja, jadi ia tidak boleh disimpan."
                  : "This video is members-only / subscription-only, so it can’t be saved."
    }
    if lower.contains("not available") || lower.contains("removed") || lower.contains("unavailable") ||
        lower.contains("410") || lower.contains("404") {
        return my ? "Video ini tidak tersedia. Mungkin sudah dipadam, dikunci wilayah, atau ada sekatan umur."
                  : "This video is unavailable — it may be removed, region-locked, or age-restricted."
    }
    if lower.contains("unsupported url") || lower.contains("no video") {
        return my ? "Pautan ini bukan video yang boleh disimpan."
                  : "Pautan ini tidak mengandungi media yang boleh disimpan."
    }
    if lower.contains("timed out") || lower.contains("timeout") || lower.contains("network") ||
        lower.contains("resolve host") || lower.contains("connection") {
        return my ? "Masalah rangkaian. Semak sambungan internet dan cuba lagi."
                  : "Network problem — check your connection and try again."
    }
    // Fall back to the first ERROR line from yt-dlp, trimmed.
    if let line = stderr.split(separator: "\n").first(where: { $0.contains("ERROR") }) {
        return String(line).replacingOccurrences(of: "ERROR: ", with: "").prefix(160).description
    }
    return my ? "Tidak dapat baca maklumat video. Pautan mungkin peribadi atau belum disokong."
              : "Could not read video info — the link may be private or unsupported."
}

enum MediaProber {
    /// Appends a line to a debug log so we can see exactly why a spawn failed
    /// inside the sandboxed GUI context.
    static func debug(_ msg: String) {
        let url = YtDlpManager.shared.supportDir.appendingPathComponent("probe.log")
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(data); try? h.close()
            } else {
                try? data.write(to: url)
            }
        }
    }

    /// Runs `yt-dlp -J` and parses metadata + the full format table.
    static func probe(url: String, settings: (browser: String, proxy: String)) async -> Result<MediaProbe, ProbeError> {
        guard let bin = YtDlpManager.shared.binaryPath else {
            return .failure(ProbeError(message: AppSettings.shared.language == .malay ? "Enjin belum sedia" : "Engine not ready"))
        }
        var args = [url, "--dump-json", "--no-playlist", "--no-warnings", "--skip-download"]
        args += youtubeSafeArgs(for: url)
        args += YtDlpManager.shared.jsRuntimeArgs
        if settings.browser != "none" { args += ["--cookies-from-browser", settings.browser] }
        if !settings.proxy.isEmpty { args += ["--proxy", settings.proxy] }
        let finalArgs = args

        let (output, errText): (String, String) = await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: bin)
            p.arguments = finalArgs
            var env = ProcessInfo.processInfo.environment
            env["HOME"] = NSHomeDirectory()
            if env["PATH"] == nil { env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin" }
            p.environment = env
            let outPipe = Pipe(), errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            do { try p.run() } catch {
                return ("", error.localizedDescription)
            }
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return (String(data: outData, encoding: .utf8) ?? "",
                    String(data: errData, encoding: .utf8) ?? "")
        }.value

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(ProbeError(message: friendlyError(from: errText)))
        }
        let rawFormats = (json["formats"] as? [[String: Any]]) ?? []
        let formats: [ProbedFormat] = rawFormats.compactMap { f in
            guard let id = f["format_id"] as? String else { return nil }
            let size = (f["filesize"] as? Int64) ?? (f["filesize_approx"] as? Int64)
            return ProbedFormat(id: id,
                                height: f["height"] as? Int,
                                ext: f["ext"] as? String ?? "",
                                vcodec: f["vcodec"] as? String,
                                acodec: f["acodec"] as? String,
                                filesize: size,
                                note: f["format_note"] as? String,
                                fps: f["fps"] as? Double)
        }
        return .success(MediaProbe(
            title: json["title"] as? String ?? url,
            thumbnail: json["thumbnail"] as? String,
            description: json["description"] as? String,
            uploader: json["uploader"] as? String,
            channel: json["channel"] as? String ?? json["uploader"] as? String,
            duration: json["duration"] as? Double,
            viewCount: json["view_count"] as? Int,
            formats: formats))
    }

    /// Full list of yt-dlp extractors (1800+), cached after first load.
    private static var cachedExtractors: [String] = []
    static func allExtractors() async -> [String] {
        if !cachedExtractors.isEmpty { return cachedExtractors }
        guard let bin = YtDlpManager.shared.binaryPath else { return [] }
        let result = await Task.detached { () -> [String] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: bin)
            p.arguments = ["--list-extractors"]
            let outPipe = Pipe(), errPipe = Pipe()
            p.standardOutput = outPipe
            p.standardError = errPipe
            do { try p.run() } catch { return [] }
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            let text = String(data: data, encoding: .utf8) ?? ""
            return text.split(separator: "\n").map(String.init)
                .filter { !$0.isEmpty && !$0.hasPrefix("[") }
        }.value
        cachedExtractors = result
        return result
    }
}

// MARK: - Argument builder (port of VidBee's yt-dlp-args)

/// YouTube now blocks the default `web` player client without a JS runtime,
/// which breaks extraction. Mirroring VidBee, we drop it so extraction stays
/// reliable out of the box.
func youtubeSafeArgs(for url: String) -> [String] {
    let u = url.lowercased()
    guard u.contains("youtube.com") || u.contains("youtu.be") else { return [] }
    return ["--extractor-args", "youtube:player_client=default,-web"]
}


enum ArgsBuilder {
    static func videoSelector(quality: QualityPreset, container: ContainerOption) -> String {
        quality.videoSelector
    }

    static func build(item: DownloadItem, settings: AppSettings, ffmpeg: String?) -> [String] {
        var args: [String] = [item.url, "--newline", "--no-playlist", "--progress-template",
                              "download:MUSIM|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s|%(progress._downloaded_bytes_str)s|%(progress._total_bytes_str)s"]
        args += youtubeSafeArgs(for: item.url)
        args += YtDlpManager.shared.jsRuntimeArgs

        if item.type == .video {
            args += ["-f", item.formatSelector ?? item.quality.videoSelector]
            switch item.container {
            case .mp4: args += ["--merge-output-format", "mp4"]
            case .mkv: args += ["--merge-output-format", "mkv"]
            case .webm: args += ["--merge-output-format", "webm"]
            case .auto: args += ["--merge-output-format", "mp4/mkv"]
            case .original: break
            }
        } else {
            args += ["-f", "bestaudio/best", "-x", "--audio-format", "mp3", "--audio-quality", "0"]
        }

        // output template (advanced naming composes prefix/date/counter/suffix)
        var template = settings.effectiveTemplate()
        if settings.channelSubfolders { template = "%(uploader)s/" + template }
        if settings.organizeByPlatform {
            template = item.platform.folderName(for: item.url) + "/" + template
        }
        args += ["-o", (settings.downloadPath as NSString).appendingPathComponent(template)]
        if settings.autoNaming, settings.advancedNaming, settings.nameCounter {
            args += ["--autonumber-start", "1"]
        }

        if settings.usesCookies {
            args += ["--cookies-from-browser", settings.resolvedCookieBrowser]
        }
        if !settings.proxy.isEmpty { args += ["--proxy", settings.proxy] }
        if settings.embedSubs, item.type == .video { args += ["--embed-subs", "--sub-langs", "en.*,-live_chat"] }
        if settings.embedThumbnail { args += ["--embed-thumbnail"] }
        if settings.embedMetadata { args += ["--embed-metadata"] }
        if settings.embedChapters, item.type == .video { args += ["--embed-chapters"] }
        // Pass the directory so yt-dlp finds both ffmpeg and ffprobe (needed
        // for metadata/thumbnail post-processing).
        if let ffmpeg { args += ["--ffmpeg-location", (ffmpeg as NSString).deletingLastPathComponent] }
        // print final filepath so we can track the saved file
        args += ["--print", "after_move:MUSIMFILE|%(filepath)s", "--no-simulate", "--no-quiet"]
        return args
    }

    static func infoArgs(url: String, settings: AppSettings) -> [String] {
        var args = [url, "--dump-json", "--no-playlist", "--no-warnings", "--skip-download"]
        args += youtubeSafeArgs(for: url)
        args += YtDlpManager.shared.jsRuntimeArgs
        if settings.usesCookies { args += ["--cookies-from-browser", settings.resolvedCookieBrowser] }
        if !settings.proxy.isEmpty { args += ["--proxy", settings.proxy] }
        return args
    }
}
