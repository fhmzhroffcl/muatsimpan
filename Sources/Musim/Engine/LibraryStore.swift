import Foundation
import AppKit
import AVFoundation

/// A file or folder inside the Musim downloads library.
struct LibraryEntry: Identifiable, Equatable {
    let id: String       // full path — stable identity for the filesystem
    let url: URL
    var name: String
    var isFolder: Bool
    var size: Int64
    var modified: Date
    var isMedia: Bool

    static func == (a: LibraryEntry, b: LibraryEntry) -> Bool { a.id == b.id && a.name == b.name }
}

/// Live view over the download folder. Renames/moves happen on the real
/// filesystem (so Finder reflects them), sticky notes live in a sidecar JSON
/// keyed by relative path so they survive app restarts.
@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published var entries: [LibraryEntry] = []
    @Published var currentFolder: URL
    @Published var notes: [String: [StickyNote]] = [:]   // relative path -> up to 5 notes
    static let maxNotesPerItem = 5
    @Published var positions: [String: CGPoint] = [:]  // relative path -> canvas position

    private let notesURL = YtDlpManager.shared.supportDir.appendingPathComponent("notes.json")
    private let positionsURL = YtDlpManager.shared.supportDir.appendingPathComponent("positions.json")
    private let mediaExts: Set<String> = ["mp4", "mkv", "webm", "mov", "m4v", "avi", "mp3", "m4a", "wav", "flac", "opus", "ogg"]

    var root: URL { URL(fileURLWithPath: AppSettings.shared.downloadPath) }
    var isAtRoot: Bool { currentFolder.standardizedFileURL == root.standardizedFileURL }

    private init() {
        currentFolder = URL(fileURLWithPath: AppSettings.shared.downloadPath)
        loadNotes()
        loadPositions()
        refresh()
    }

    // MARK: Canvas positions

    /// Stable position for an entry: stored value or an auto grid slot.
    func position(for entry: LibraryEntry, index: Int, canvasWidth: CGFloat) -> CGPoint {
        if let p = positions[relPath(entry.url)] { return p }
        // Start below the floating header so the first row is never clipped.
        let perRow = max(1, Int((canvasWidth - 120) / 230))
        let col = index % perRow, row = index / perRow
        return CGPoint(x: 150 + CGFloat(col) * 230, y: 220 + CGFloat(row) * 210)
    }

    func setPosition(_ point: CGPoint, for entry: LibraryEntry) {
        positions[relPath(entry.url)] = point
        savePositions()
    }

    private func loadPositions() {
        guard let data = try? Data(contentsOf: positionsURL),
              let raw = try? JSONDecoder().decode([String: [CGFloat]].self, from: data) else { return }
        positions = raw.compactMapValues { $0.count == 2 ? CGPoint(x: $0[0], y: $0[1]) : nil }
    }

    private func savePositions() {
        let raw = positions.mapValues { [$0.x, $0.y] }
        if let data = try? JSONEncoder().encode(raw) { try? data.write(to: positionsURL) }
    }

    func refresh() {
        // download path may have changed in settings
        AppSettings.shared.ensureDownloadDirectory()
        if !currentFolder.path.hasPrefix(root.path) { currentFolder = root }
        let fm = FileManager.default
        try? fm.createDirectory(at: currentFolder, withIntermediateDirectories: true)
        let urls = (try? fm.contentsOfDirectory(at: currentFolder,
                                                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                                                options: [.skipsHiddenFiles])) ?? []
        entries = urls.compactMap { url in
            let vals = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            let isDir = vals?.isDirectory ?? false
            let ext = url.pathExtension.lowercased()
            if !isDir && !mediaExts.contains(ext) && ext != "" { return nil }
            return LibraryEntry(id: url.path, url: url, name: url.lastPathComponent, isFolder: isDir,
                                size: Int64(vals?.fileSize ?? 0),
                                modified: vals?.contentModificationDate ?? .distantPast,
                                isMedia: !isDir && self.mediaExts.contains(ext))
        }
        .sorted { a, b in
            if a.isFolder != b.isFolder { return a.isFolder }
            return a.modified > b.modified
        }
    }

    /// Every media file under the root (recursive) — for the Media & Player tabs.
    func allMedia() -> [LibraryEntry] {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                                     options: [.skipsHiddenFiles]) else { return [] }
        var out: [LibraryEntry] = []
        for case let url as URL in en {
            let ext = url.pathExtension.lowercased()
            guard mediaExts.contains(ext) else { continue }
            let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            out.append(LibraryEntry(id: url.path, url: url, name: url.lastPathComponent, isFolder: false,
                                    size: Int64(vals?.fileSize ?? 0),
                                    modified: vals?.contentModificationDate ?? .distantPast, isMedia: true))
        }
        return out.sorted { $0.modified > $1.modified }
    }

    /// Duplicate a file within its folder.
    func copy(_ entry: LibraryEntry) {
        let base = entry.url.deletingPathExtension().lastPathComponent
        let ext = entry.url.pathExtension
        var dest = entry.url.deletingLastPathComponent().appendingPathComponent("\(base) copy.\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = entry.url.deletingLastPathComponent().appendingPathComponent("\(base) copy \(n).\(ext)"); n += 1
        }
        try? FileManager.default.copyItem(at: entry.url, to: dest)
        refresh()
    }

    func open(folder: URL) { currentFolder = folder; refresh() }
    func goUp() {
        guard !isAtRoot else { return }
        currentFolder = currentFolder.deletingLastPathComponent()
        refresh()
    }

    // MARK: Filesystem operations (reflected in Finder)

    func rename(_ entry: LibraryEntry, to newName: String) {
        let clean = newName.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, clean != entry.name else { return }
        let dest = entry.url.deletingLastPathComponent().appendingPathComponent(clean)
        do {
            try FileManager.default.moveItem(at: entry.url, to: dest)
            moveNote(from: entry.url, to: dest)
            refresh()
        } catch { NSSound.beep() }
    }

    @discardableResult
    func newFolder(named name: String = "New Folder", in parent: URL? = nil) -> LibraryEntry? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = clean.isEmpty ? (AppSettings.shared.language == .malay ? "Folder Baharu" : "New Folder") : clean
        let parent = parent ?? currentFolder
        var dest = parent.appendingPathComponent(base, isDirectory: true)
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = parent.appendingPathComponent("\(base) \(n)", isDirectory: true); n += 1
        }
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        refresh()
        return entry(for: dest)
    }

    /// Move a file into a folder (drag & drop target).
    func move(path: String, into folder: LibraryEntry) {
        move(paths: [path], into: folder)
    }

    /// Move multiple files/folders into a folder. Existing names are preserved
    /// with " 2", " 3", etc. so drops never fail because of a filename clash.
    func move(paths: [String], into folder: LibraryEntry) {
        guard folder.isFolder else { return }
        var moved = false
        for path in paths {
            let src = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: src.path) else { continue }
            let srcPath = src.standardizedFileURL.path
            let folderPath = folder.url.standardizedFileURL.path
            guard srcPath != folderPath, !folderPath.hasPrefix(srcPath + "/") else { continue }

            let dest = uniqueDestination(for: src.lastPathComponent, in: folder.url)
            do {
                try FileManager.default.moveItem(at: src, to: dest)
                moveNote(from: src, to: dest)
                moved = true
            } catch {
                NSSound.beep()
            }
        }
        if moved { refresh() }
    }

    func trash(_ entry: LibraryEntry) {
        try? FileManager.default.trashItem(at: entry.url, resultingItemURL: nil)
        notes[relPath(entry.url)] = nil
        saveNotes()
        refresh()
    }

    func revealInFinder(_ entry: LibraryEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
    }

    private func entry(for url: URL) -> LibraryEntry? {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return LibraryEntry(id: url.path,
                            url: url,
                            name: url.lastPathComponent,
                            isFolder: isDir.boolValue,
                            size: (attrs?[.size] as? Int64) ?? 0,
                            modified: (attrs?[.modificationDate] as? Date) ?? Date(),
                            isMedia: !isDir.boolValue && mediaExts.contains(url.pathExtension.lowercased()))
    }

    private func uniqueDestination(for filename: String, in folder: URL) -> URL {
        let original = folder.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: original.path) else { return original }

        let source = URL(fileURLWithPath: filename)
        let base = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var n = 2
        while true {
            let candidateName = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    // MARK: Sticky notes

    private func relPath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: root.path + "/", with: "")
    }

    /// All notes pinned to an entry (up to `maxNotesPerItem`).
    func notes(for entry: LibraryEntry) -> [StickyNote] { notes[relPath(entry.url)] ?? [] }

    /// First note (for compact indicators).
    func note(for entry: LibraryEntry) -> StickyNote? { notes[relPath(entry.url)]?.first }

    /// Add a note if there's room. Returns false when the item already has 5.
    @discardableResult
    func addNote(_ note: StickyNote, for entry: LibraryEntry) -> Bool {
        let key = relPath(entry.url)
        var list = notes[key] ?? []
        guard list.count < Self.maxNotesPerItem else { return false }
        list.append(note)
        notes[key] = list
        saveNotes()
        return true
    }

    /// Replace an existing note (matched by id) or append it.
    func upsertNote(_ note: StickyNote, for entry: LibraryEntry) {
        let key = relPath(entry.url)
        var list = notes[key] ?? []
        if let i = list.firstIndex(where: { $0.id == note.id }) { list[i] = note }
        else if list.count < Self.maxNotesPerItem { list.append(note) }
        notes[key] = list.isEmpty ? nil : list
        saveNotes()
    }

    func removeNote(id: String, for entry: LibraryEntry) {
        let key = relPath(entry.url)
        var list = notes[key] ?? []
        list.removeAll { $0.id == id }
        notes[key] = list.isEmpty ? nil : list
        saveNotes()
    }

    /// Every note across the library, paired with the entry it links to — for
    /// the notes browser.
    func allNotes() -> [(entry: LibraryEntry, note: StickyNote)] {
        var out: [(LibraryEntry, StickyNote)] = []
        for (key, list) in notes {
            let url = root.appendingPathComponent(key)
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            guard exists else { continue }
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let entry = LibraryEntry(id: url.path, url: url, name: url.lastPathComponent,
                                     isFolder: isDir.boolValue,
                                     size: (attrs?[.size] as? Int64) ?? 0,
                                     modified: (attrs?[.modificationDate] as? Date) ?? Date(),
                                     isMedia: mediaExts.contains(url.pathExtension.lowercased()))
            for n in list { out.append((entry, n)) }
        }
        return out.sorted { $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending }
    }

    private func moveNote(from: URL, to: URL) {
        let old = relPath(from)
        if let n = notes[old] { notes[relPath(to)] = n; notes[old] = nil; saveNotes() }
        if let p = positions[old] { positions[relPath(to)] = p; positions[old] = nil; savePositions() }
    }

    private func loadNotes() {
        guard let data = try? Data(contentsOf: notesURL) else { return }
        // Current format: [path: [StickyNote]]
        if let decoded = try? JSONDecoder().decode([String: [StickyNote]].self, from: data) {
            notes = decoded
        } else if let old = try? JSONDecoder().decode([String: StickyNote].self, from: data) {
            // Migrate the old single-note-per-path format.
            notes = old.mapValues { [$0] }
            saveNotes()
        }
    }
    private func saveNotes() {
        if let data = try? JSONEncoder().encode(notes) { try? data.write(to: notesURL) }
    }

    // MARK: Clipping (trim/export a segment — AVFoundation, no ffmpeg needed)

    func exportClip(of entry: LibraryEntry, start: Double, end: Double, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVURLAsset(url: entry.url)
        let base = entry.url.deletingPathExtension().lastPathComponent
        let isAudio = ["mp3", "m4a", "wav", "flac", "opus", "ogg"].contains(entry.url.pathExtension.lowercased())
        let outExt = isAudio ? "m4a" : "mp4"
        var out = entry.url.deletingLastPathComponent().appendingPathComponent("\(base) Clip.\(outExt)")
        var n = 2
        while FileManager.default.fileExists(atPath: out.path) {
            out = entry.url.deletingLastPathComponent().appendingPathComponent("\(base) Clip \(n).\(outExt)"); n += 1
        }
        guard let session = AVAssetExportSession(asset: asset, presetName: isAudio ? AVAssetExportPresetAppleM4A : AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "Musim", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot export this file"])))
            return
        }
        session.outputURL = out
        session.outputFileType = isAudio ? .m4a : .mp4
        session.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                        end: CMTime(seconds: end, preferredTimescale: 600))
        session.exportAsynchronously {
            Task { @MainActor in
                if session.status == .completed {
                    self.refresh()
                    completion(.success(out))
                } else {
                    completion(.failure(session.error ?? NSError(domain: "Musim", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])))
                }
            }
        }
    }

    // MARK: Full edit export (trim + speed + aspect ratio + resolution)

    struct EditOptions {
        var start: Double
        var end: Double
        var speed: Double = 1.0        // 0.5 = slow-mo, 2.0 = fast
        var aspect: AspectRatio = .original
        var maxHeight: Int? = nil      // nil = keep source height
        var cropX: Double = 0.5        // 0...1, horizontal crop focus
        var cropY: Double = 0.5        // 0...1, vertical crop focus
    }
    enum AspectRatio: String, CaseIterable, Identifiable {
        case original, square = "1:1", vertical = "9:16", wide = "16:9"
        var id: String { rawValue }
        var ratio: CGFloat? {
            switch self {
            case .original: return nil
            case .square: return 1
            case .vertical: return 9.0/16.0
            case .wide: return 16.0/9.0
            }
        }
    }

    func exportEdit(of entry: LibraryEntry, options: EditOptions, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let ffmpeg = YtDlpManager.shared.ffmpegPath else {
            completion(.failure(NSError(domain: "Musim", code: 5,
                                         userInfo: [NSLocalizedDescriptionKey: "FFmpeg is not available"])))
            return
        }
        let base = entry.url.deletingPathExtension().lastPathComponent
        var out = entry.url.deletingLastPathComponent().appendingPathComponent("\(base) Edit.mp4")
        var n = 2
        while FileManager.default.fileExists(atPath: out.path) {
            out = entry.url.deletingLastPathComponent().appendingPathComponent("\(base) Edit \(n).mp4")
            n += 1
        }

        let clipDuration = max(0.1, options.end - options.start)
        var videoFilters = ["setpts=PTS/\(options.speed)"]
        if let ratio = options.aspect.ratio {
            let crop = "crop=if(gt(iw/ih\\,\(ratio))\\,ih*\(ratio)\\,iw):if(gt(iw/ih\\,\(ratio))\\,ih\\,iw/\(ratio)):(iw-ow)*\(options.cropX):(ih-oh)*\(options.cropY)"
            videoFilters.append(crop)
        }
        if let maxHeight = options.maxHeight {
            videoFilters.append("scale=-2:\(maxHeight)")
        }

        var args = ["-hide_banner", "-loglevel", "error", "-y",
                    "-ss", String(format: "%.3f", options.start), "-i", entry.url.path,
                    "-t", String(format: "%.3f", clipDuration),
                    "-map", "0:v:0", "-map", "0:a?",
                    "-vf", videoFilters.joined(separator: ","),
                    "-c:v", "libx264", "-crf", "18", "-preset", "medium",
                    "-pix_fmt", "yuv420p"]
        if options.speed != 1.0 {
            args += ["-af", "atempo=\(options.speed)"]
        }
        args += ["-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out.path]

        Task.detached {
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: ffmpeg)
            process.arguments = args
            process.standardError = errorPipe
            do {
                try process.run()
                process.waitUntilExit()
                let errorText = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                await MainActor.run {
                    if process.terminationStatus == 0 {
                        self.refresh()
                        completion(.success(out))
                    } else {
                        let detail = errorText.trimmingCharacters(in: .whitespacesAndNewlines)
                        completion(.failure(NSError(domain: "Musim", code: 6,
                                                     userInfo: [NSLocalizedDescriptionKey: detail.isEmpty ? "Export failed" : detail])))
                    }
                }
            } catch {
                await MainActor.run { completion(.failure(error)) }
            }
        }
    }
}
