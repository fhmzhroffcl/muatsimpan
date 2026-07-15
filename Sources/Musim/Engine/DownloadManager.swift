import Foundation
import AppKit
import UserNotifications

/// Download queue + history — the heart of Musim. Runs yt-dlp processes with
/// bounded concurrency, parses live progress, persists history to JSON.
@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var items: [DownloadItem] = []
    private var processes: [String: Process] = [:]
    private let settings = AppSettings.shared
    private let historyURL: URL

    var active: [DownloadItem] { items.filter { [.pending, .downloading, .processing].contains($0.status) } }
    var history: [DownloadItem] { items.filter { [.completed, .error, .cancelled].contains($0.status) } }

    /// Completed downloads, newest first — kept visible on the download page
    /// (faded). The page shows up to 50; older ones live on in Activity history.
    var recentlyFinished: [DownloadItem] {
        items.filter { $0.status == .completed }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private init() {
        historyURL = YtDlpManager.shared.supportDir.appendingPathComponent("history.json")
        load()
        // anything left mid-download from a previous run is stale
        for i in items.indices where [.pending, .downloading, .processing].contains(items[i].status) {
            items[i].status = .cancelled
        }
    }

    // MARK: Queue API

    /// Enqueue fully-configured items from the pre-download options sheet.
    func enqueue(prepared: [DownloadItem]) {
        for var item in prepared {
            item.status = .pending
            item.platform = Platform.detect(from: item.url)
            items.insert(item, at: 0)
        }
        pump()
    }

    func enqueue(urls: [String], type: MediaType? = nil) {
        for url in urls {
            var item = DownloadItem(url: url, title: url, type: type ?? settings.oneClickType)
            item.platform = Platform.detect(from: url)
            item.quality = settings.oneClickQuality
            item.container = settings.container
            items.insert(item, at: 0)
            fetchInfo(for: item.id)
        }
        pump()
    }

    func cancel(_ id: String) {
        processes[id]?.terminate()
        processes[id] = nil
        update(id) { $0.status = .cancelled }
        pump()
    }

    func retry(_ id: String) {
        update(id) {
            $0.status = .pending
            $0.progress = DownloadProgressInfo()
            $0.errorMessage = nil
        }
        pump()
    }

    func remove(_ id: String) {
        processes[id]?.terminate()
        items.removeAll { $0.id == id }
        save()
    }

    func clearHistory() {
        items.removeAll { [.completed, .error, .cancelled].contains($0.status) }
        save()
    }

    // MARK: Info fetch (title/thumbnail/metadata before download)

    private func fetchInfo(for id: String) {
        guard let bin = YtDlpManager.shared.binaryPath,
              let item = items.first(where: { $0.id == id }) else { return }
        let args = ArgsBuilder.infoArgs(url: item.url, settings: settings)
        Task.detached { [weak self] in
            let out = Self.run(bin: bin, args: args)
            guard let data = out.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            await MainActor.run {
                self?.update(id) { it in
                    it.title = json["title"] as? String ?? it.title
                    it.thumbnailURL = json["thumbnail"] as? String
                    it.duration = json["duration"] as? Double
                    it.uploader = json["uploader"] as? String
                    it.channel = json["channel"] as? String ?? json["uploader"] as? String
                    it.descriptionText = json["description"] as? String
                    it.viewCount = json["view_count"] as? Int
                    it.formatNote = (json["resolution"] as? String) ?? (json["format_note"] as? String)
                    it.ext = json["ext"] as? String
                    it.audioFormat = json["acodec"] as? String
                }
            }
        }
    }

    nonisolated private static func run(bin: String, args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: Scheduler

    private func pump() {
        let running = items.filter { $0.status == .downloading || $0.status == .processing }.count
        var slots = settings.maxConcurrentDownloads - running
        guard slots > 0 else { save(); return }
        for item in items.reversed() where item.status == .pending {
            guard slots > 0 else { break }
            start(item)
            slots -= 1
        }
        save()
    }

    private func start(_ item: DownloadItem) {
        guard let bin = YtDlpManager.shared.binaryPath else {
            update(item.id) { $0.status = .error; $0.errorMessage = settings.language == .malay ? "Enjin yt-dlp belum dipasang" : "yt-dlp is not installed yet" }
            return
        }
        settings.ensureDownloadDirectory()
        update(item.id) { $0.status = .downloading }
        if settings.notifyOnComplete {
                notify(title: item.type == .video ? (settings.language == .malay ? "Sedang menyimpan video" : "Saving video")
                                              : (settings.language == .malay ? "Sedang menyimpan audio" : "Saving audio"),
                   body: item.title)
        }

        let args = ArgsBuilder.build(item: item, settings: settings, ffmpeg: YtDlpManager.shared.ffmpegPath)
        MediaProber.debug("DL start args=\(args.joined(separator: " "))")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = NSHomeDirectory()
        if env["PATH"] == nil { env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin" }
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        let id = item.id

        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = String(data: handle.availableData, encoding: .utf8) ?? ""
            guard !chunk.isEmpty else { return }
            Task { @MainActor in self?.handleOutput(id: id, chunk: chunk) }
        }
        err.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = String(data: handle.availableData, encoding: .utf8) ?? ""
            guard !chunk.isEmpty else { return }
            Task { @MainActor in self?.update(id) { $0.log += chunk } }
        }
        p.terminationHandler = { [weak self] proc in
            Task { @MainActor in self?.finished(id: id, code: proc.terminationStatus) }
        }
        processes[id] = p
        do { try p.run() } catch {
            update(id) { $0.status = .error; $0.errorMessage = error.localizedDescription }
            processes[id] = nil
        }
    }

    private func handleOutput(id: String, chunk: String) {
        for line in chunk.split(separator: "\n") {
            if line.hasPrefix("MUSIM|") {
                let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if parts.count >= 6 {
                    let percent = Double(parts[1].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                    update(id) {
                        $0.status = .downloading
                        $0.progress.percent = percent
                        $0.progress.speed = parts[2].trimmingCharacters(in: .whitespaces)
                        $0.progress.eta = parts[3].trimmingCharacters(in: .whitespaces)
                        $0.progress.downloaded = parts[4].trimmingCharacters(in: .whitespaces)
                        $0.progress.total = parts[5].trimmingCharacters(in: .whitespaces)
                    }
                }
            } else if line.hasPrefix("MUSIMFILE|") {
                let path = String(line.dropFirst("MUSIMFILE|".count))
                update(id) { $0.savedFilePath = path }
            } else if line.contains("[Merger]") || line.contains("[ExtractAudio]") || line.contains("[EmbedThumbnail]") {
                update(id) { $0.status = .processing; $0.log += line + "\n" }
            } else {
                update(id) { $0.log += line + "\n" }
            }
        }
    }

    private func finished(id: String, code: Int32) {
        processes[id]?.standardOutput.flatMap { ($0 as? Pipe)?.fileHandleForReading.readabilityHandler = nil }
        processes[id]?.standardError.flatMap { ($0 as? Pipe)?.fileHandleForReading.readabilityHandler = nil }
        processes[id] = nil
        guard let item = items.first(where: { $0.id == id }) else { return }
        MediaProber.debug("DL finished code=\(code) status=\(item.status.rawValue) logtail=\(String(item.log.suffix(500)))")
        if item.status == .cancelled { pump(); return }
        if code == 0 {
            update(id) {
                $0.status = .completed
                $0.progress.percent = 100
                $0.completedAt = Date()
                if let path = $0.savedFilePath,
                   let size = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64 {
                    $0.fileSize = size
                }
            }
            LibraryStore.shared.refresh()
            if let done = items.first(where: { $0.id == id }) { ReportLogger.shared.log(done) }
            if settings.notifyOnComplete {
                notify(title: item.type == .video ? (settings.language == .malay ? "Video disimpan" : "Video saved")
                                                  : (settings.language == .malay ? "Audio disimpan" : "Music saved"),
                       body: item.title)
            }
        } else {
            update(id) {
                $0.status = .error
                $0.errorMessage = String($0.log.suffix(400))
            }
            if settings.notifyOnComplete {
                notify(title: settings.language == .malay ? "Simpanan gagal" : "Save failed", body: item.title)
            }
        }
        pump()
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// The download record for a saved file, if Musim downloaded it — used to
    /// index Library search by platform, channel, and original title.
    func record(forPath path: String) -> DownloadItem? {
        items.first { $0.savedFilePath == path }
    }

    // MARK: File actions

    func revealInFinder(_ item: DownloadItem) {
        if let path = item.savedFilePath, FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: settings.downloadPath))
        }
    }

    func play(_ item: DownloadItem) {
        guard let path = item.savedFilePath, FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: Persistence

    private func update(_ id: String, _ mutate: (inout DownloadItem) -> Void) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[idx])
    }

    private func save() {
        // keep log sizes bounded in persisted history
        var toSave = items
        for i in toSave.indices { toSave[i].log = String(toSave[i].log.suffix(2000)) }
        if let data = try? JSONEncoder().encode(toSave) {
            try? data.write(to: historyURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        items = decoded
    }
}
