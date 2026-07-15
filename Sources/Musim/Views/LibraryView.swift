import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, videos, folders, notes
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return loc("lib.all")
        case .videos: return loc("lib.videos")
        case .folders: return loc("lib.folders")
        case .notes: return loc("lib.notes")
        }
    }
    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .videos: return "film"
        case .folders: return "folder"
        case .notes: return "note.text"
        }
    }
}

enum LibraryTab: String, CaseIterable, Identifiable {
    case folders, media, player, editor
    var id: String { rawValue }
    var key: String {
        switch self {
        case .folders: return "lib.folders"
        case .media: return "lib.media"
        case .player: return "lib.player"
        case .editor: return "lib.editor"
        }
    }
    var symbol: String {
        switch self {
        case .folders: return "folder"
        case .media: return "square.grid.2x2"
        case .player: return "play.circle"
        case .editor: return "slider.horizontal.below.rectangle"
        }
    }
}

extension Notification.Name {
    static let musimPlayMedia = Notification.Name("musim.playMedia")
}

private func playMediaInApp(_ url: URL) {
    NotificationCenter.default.post(name: .musimPlayMedia, object: nil, userInfo: ["url": url])
}

/// Whether a library entry matches a search query across its indexed fields:
/// name, file type/format, containing folder, date, and — if Musim downloaded
/// it — the source platform, channel, and original title.
@MainActor
func libraryEntryMatches(_ e: LibraryEntry, query q: String) -> Bool {
    let query = q.trimmingCharacters(in: .whitespaces)
    guard !query.isEmpty else { return true }
    var hay = [e.name,
               e.url.pathExtension,
               e.url.deletingLastPathComponent().lastPathComponent]
    let df = DateFormatter(); df.dateStyle = .medium
    hay.append(df.string(from: e.modified))
    if let rec = DownloadManager.shared.record(forPath: e.url.path) {
        hay.append(contentsOf: [rec.title, rec.platform.label, rec.channel ?? "", rec.uploader ?? ""])
    }
    return hay.joined(separator: " ").localizedCaseInsensitiveContains(query)
}

/// Library with a floating navbar: Folders (canvas), Media (Photos-style
/// timeline), Player (built-in), and Editor (clip / crop / speed).
struct LibraryView: View {
    var onAddToArchive: () -> Void = {}
    @ObservedObject private var library = LibraryStore.shared
    @State private var tab: LibraryTab = .media
    @State private var search = ""
    @State private var clipEntry: LibraryEntry?
    @State private var noteEntry: LibraryEntry?
    @State private var dragOverFolder: String?
    @State private var selection: Set<String> = []
    @State private var selecting = false
    @State private var sortMode: SortMode = .messy
    @State private var showNotes = false
    @State private var canvasZoom: CGFloat = 1
    @State private var showGroupDialog = false
    @State private var groupName = ""
    @State private var requestedPlayerURL: URL?
    @GestureState private var pinchZoom: CGFloat = 1
    private var my: Bool { AppSettings.shared.language == .malay }

    enum SortMode: String, CaseIterable { case messy, name, date
        var next: SortMode { self == .messy ? .name : self == .name ? .date : .messy }
        var symbol: String { self == .messy ? "square.on.square.dashed" : self == .name ? "textformat.abc" : "calendar" }
        var label: String {
            let my = AppSettings.shared.language == .malay
            switch self {
            case .messy: return my ? "Bebas" : "Free"
            case .name: return my ? "Nama" : "Name"
            case .date: return my ? "Tarikh" : "Date"
            }
        }
    }

    private let canvasSize = CGSize(width: 2600, height: 1800)
    static let cardSize = CGSize(width: 200, height: 178)
    private var liveZoom: CGFloat { min(1.55, max(0.65, canvasZoom * pinchZoom)) }

    private var folderEntries: [LibraryEntry] {
        var list = search.isEmpty ? library.entries
            : library.entries.filter { libraryEntryMatches($0, query: search) }
        switch sortMode {
        case .messy: break
        case .name: list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date: list.sort { $0.modified > $1.modified }
        }
        return list
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch tab {
                case .folders: foldersCanvas
                case .media:   MediaTabView(search: search, selecting: $selecting, selection: $selection, clipEntry: $clipEntry, noteEntry: $noteEntry)
                case .player:  PlayerTabView(search: search, requestedURL: requestedPlayerURL)
                case .editor:  EditorTabView()
                }
            }
            // Glass fade under the header so content scrolling up refracts and
            // fades out instead of colliding with the title.
            VStack(spacing: 0) {
                Rectangle().fill(.ultraThinMaterial)
                    .frame(height: 96)
                    .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                Spacer()
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            header
            floatingNav
        }
        .background(Theme.bg)
        .onAppear { library.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .musimPlayMedia)) { note in
            guard let url = note.userInfo?["url"] as? URL else { return }
            requestedPlayerURL = url
            tab = .player
        }
        .sheet(item: $clipEntry) { ClipEditorView(entry: $0) }
        .sheet(item: $noteEntry) { NoteEditorView(entry: $0) }
    }

    // MARK: Folders canvas

    private var foldersCanvas: some View {
        GeometryReader { _ in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    DotGridBackground().frame(width: canvasSize.width, height: canvasSize.height)
                        .patterned(tint: Theme.accent, opacity: 0.05)
                    ForEach(Array(folderEntries.enumerated()), id: \.element.id) { idx, entry in
                        let organized = sortMode != .messy
                        let pos = organized ? gridPos(idx) : library.position(for: entry, index: idx, canvasWidth: canvasSize.width)
                        CanvasCard(entry: entry, basePosition: pos, organized: organized,
                                   clipEntry: $clipEntry, noteEntry: $noteEntry, dragOverFolder: $dragOverFolder,
                                   selection: $selection, selecting: selecting,
                                   allEntries: folderEntries, index: idx, canvasWidth: canvasSize.width)
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
                .scaleEffect(liveZoom, anchor: .topLeading)
                .frame(width: canvasSize.width * liveZoom, height: canvasSize.height * liveZoom, alignment: .topLeading)
            }
            .gesture(
                MagnificationGesture()
                    .updating($pinchZoom) { value, state, _ in state = value }
                    .onEnded { value in canvasZoom = min(1.55, max(0.65, canvasZoom * value)) }
            )
            .overlay(alignment: .bottomTrailing) {
                ZoomHUD(zoom: $canvasZoom)
                    .padding(.trailing, 24)
                    .padding(.bottom, 84)
            }
        }
    }

    // MARK: Header (title + search + actions)

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    if tab == .folders && !library.isAtRoot {
                        Button { withAnimation { library.goUp() } } label: {
                            Image(systemName: "chevron.left.circle.fill").font(.title3).foregroundStyle(Theme.textSecondary)
                        }.buttonStyle(.plain)
                    }
                    Text(tab == .folders && !library.isAtRoot ? library.currentFolder.lastPathComponent : loc("nav.library"))
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.textPrimary)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                TextField(loc("lib.search"), text: $search).textFieldStyle(.plain).foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Capsule().fill(Theme.surface))
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
            .frame(maxWidth: 260)

            if tab == .media {
                headerButton("plus", my ? "Tambah ke arkib" : "Add to archive", onAddToArchive)
            }

            headerButton("note.text", loc("lib.allNotes")) {
                showNotes.toggle()
            }
            .popover(isPresented: $showNotes, arrowEdge: .bottom) {
                NotesBrowser(onOpen: { e in showNotes = false; noteEntry = e })
            }

            if tab == .folders {
                headerButton(sortMode.symbol, my ? "Susun: \(sortMode.label)" : "Arrange: \(sortMode.label)") {
                    withAnimation(Theme.smooth) { sortMode = sortMode.next }
                }
                headerButton("folder.badge.plus", loc("lib.newFolder")) { library.newFolder() }
            }
            if (tab == .folders || tab == .media) && selecting && !selection.isEmpty {
                headerButton("folder.fill.badge.plus", my ? "Kumpul ke folder" : "Group into folder") {
                    groupName = defaultGroupName
                    showGroupDialog = true
                }
            }
            if tab == .folders || tab == .media {
                headerButton(selecting ? "checkmark.circle.fill" : "checkmark.circle", my ? "Pilih" : "Select") {
                    selecting.toggle(); if !selecting { selection.removeAll() }
                }
            }
        }
        .padding(.horizontal, 24).padding(.top, 40)
        .alert(my ? "Kumpul ke folder" : "Group into folder", isPresented: $showGroupDialog) {
            TextField(my ? "Nama folder" : "Folder name", text: $groupName)
            Button(my ? "Kumpul" : "Group") { groupSelectedIntoFolder() }
                .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(loc("common.cancel"), role: .cancel) {}
        } message: {
            Text(my ? "Media yang dipilih akan dipindahkan ke folder baharu." : "Selected media will be moved into a new folder.")
        }
    }

    private var defaultGroupName: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return my ? "Koleksi \(df.string(from: Date()))" : "Collection \(df.string(from: Date()))"
    }

    private func groupSelectedIntoFolder() {
        let paths = selectedMediaPaths()
        guard !paths.isEmpty else { return }
        let parent = tab == .folders ? library.currentFolder : library.root
        guard let folder = library.newFolder(named: groupName, in: parent) else { return }
        withAnimation(Theme.smooth) {
            library.move(paths: paths, into: folder)
            selection.removeAll()
            selecting = false
        }
    }

    private func selectedMediaPaths() -> [String] {
        let selected = Set(selection)
        let candidates = tab == .folders ? folderEntries : library.allMedia()
        return candidates
            .filter { selected.contains($0.id) && !$0.isFolder && $0.isMedia }
            .map(\.url.path)
    }

    private func gridPos(_ index: Int) -> CGPoint {
        let perRow = max(1, Int((canvasSize.width - 120) / 230))
        let col = index % perRow, row = index / perRow
        return CGPoint(x: 150 + CGFloat(col) * 230, y: 220 + CGFloat(row) * 210)
    }

    private func headerButton(_ icon: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.surface)).overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                .foregroundStyle(Theme.textPrimary)
        }.buttonStyle(.plain).help(help)
    }

    // MARK: Floating navbar

    private var floatingNav: some View {
        VStack {
            Spacer()
            HStack(spacing: 4) {
                ForEach(LibraryTab.allCases) { t in
                    Button {
                        withAnimation(Theme.bouncy) { tab = t }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: t.symbol).font(.system(size: 12, weight: .semibold))
                            if tab == t { Text(loc(t.key)).font(.caption.weight(.semibold)) }
                        }
                        .padding(.horizontal, tab == t ? 14 : 11).padding(.vertical, 9)
                        .background(Capsule().fill(tab == t ? Theme.accent : Color.clear))
                        .foregroundStyle(tab == t ? Color.white : Theme.textSecondary)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Capsule().fill(Theme.bgElevated).shadow(color: .black.opacity(0.24), radius: 18, y: 8))
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
            .padding(.bottom, 22)
        }
    }
}

struct ZoomHUD: View {
    @Binding var zoom: CGFloat
    @State private var hovering = false
    private var my: Bool { AppSettings.shared.language == .malay }

    var body: some View {
        HStack(spacing: 8) {
            Button { withAnimation(Theme.snappy) { zoom = max(0.65, zoom - 0.1) } } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.plain)
            Slider(value: Binding(get: { Double(zoom) }, set: { zoom = CGFloat($0) }), in: 0.65...1.55)
                .frame(width: 116)
            Text("\(Int(zoom * 100))%")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 42, alignment: .trailing)
            Button { withAnimation(Theme.snappy) { zoom = min(1.55, zoom + 0.1) } } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
        .opacity(hovering ? 1 : 0.58)
        .onHover { hovering = $0 }
        .help(my ? "Zum Pustaka" : "Library zoom")
    }
}

// MARK: - Media tab (Photos-style, grouped by day)

struct MediaTabView: View {
    let search: String
    @Binding var selecting: Bool
    @Binding var selection: Set<String>
    @Binding var clipEntry: LibraryEntry?
    @Binding var noteEntry: LibraryEntry?
    @ObservedObject private var library = LibraryStore.shared
    @State private var media: [LibraryEntry] = []
    @State private var showStats = false
    @State private var showLocationSheet = false

    private let cols = [GridItem(.adaptive(minimum: 150, maximum: 210), spacing: 16)]

    private var filtered: [LibraryEntry] {
        search.isEmpty ? media : media.filter { libraryEntryMatches($0, query: search) }
    }
    private var grouped: [(String, [LibraryEntry])] {
        let df = DateFormatter(); df.dateStyle = .full
        let groups = Dictionary(grouping: filtered) { df.string(from: $0.modified) }
        return groups.sorted { ($0.value.first?.modified ?? .distantPast) > ($1.value.first?.modified ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                archiveSummary
                if filtered.isEmpty {
                    emptyState.padding(.top, 120)
                } else {
                    ForEach(grouped, id: \.0) { day, items in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle().fill(Theme.accent).frame(width: 6, height: 6)
                                Text(day).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textPrimary)
                                Text("\(items.count)").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                            }
                            LazyVGrid(columns: cols, spacing: 16) {
                                ForEach(items) { entry in
                                    MediaCell(entry: entry, selecting: selecting,
                                              selected: selection.contains(entry.id),
                                              onTap: { toggle(entry) },
                                              clipEntry: $clipEntry, noteEntry: $noteEntry)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 96).padding(.bottom, 96)
        }
        .background(Theme.bg)
        .onAppear { media = library.allMedia() }
        .onChange(of: library.entries.map(\.id)) { _, _ in media = library.allMedia() }
        .sheet(isPresented: $showStats) { ArchiveStatsSheet(onClose: { showStats = false }) }
        .sheet(isPresented: $showLocationSheet) { SaveLocationSheet(onClose: { showLocationSheet = false }) }
    }

    private var archiveSummary: some View {
        let my = AppSettings.shared.language == .malay
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(my ? "Simpanan anda" : "Your archive")
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { showStats = true } label: {
                    Label(my ? "Statistik" : "Insights", systemImage: "chart.pie.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accentSoft))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .help(my ? "Lihat statistik simpanan" : "See archive insights")
            }
            Text("\(media.count) \(my ? "item" : "items") · \(archiveSize) \(my ? "dalam simpanan anda" : "in your archive")")
                .font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { showLocationSheet = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "folder.fill").font(.caption2).foregroundStyle(Theme.accent)
                    Text(my ? "Lokasi simpanan:" : "Archive location:")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    Text(library.root.path).font(.caption.monospaced()).foregroundStyle(Theme.textPrimary).lineLimit(1).truncationMode(.middle)
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(my ? "Tukar lokasi simpanan" : "Change save location")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous).fill(Theme.surface.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    private var archiveSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: media.reduce(0) { $0 + $1.size })
    }

    private func toggle(_ e: LibraryEntry) {
        if selecting {
            if selection.contains(e.id) { selection.remove(e.id) } else { selection.insert(e.id) }
        } else {
            playMediaInApp(e.url)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2").font(.system(size: 44)).foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text(AppSettings.shared.language == .malay
                 ? "Platform boleh padam bila-bila. Simpan yang penting, milik anda selamanya."
                 : "Platforms can remove things anytime. Save what matters — yours to keep.")
                .font(.title3.weight(.medium)).multilineTextAlignment(.center).foregroundStyle(Theme.textSecondary)
        }.frame(maxWidth: .infinity)
    }
}

struct MediaCell: View {
    let entry: LibraryEntry
    let selecting: Bool
    let selected: Bool
    let onTap: () -> Void
    @Binding var clipEntry: LibraryEntry?
    @Binding var noteEntry: LibraryEntry?
    @ObservedObject private var library = LibraryStore.shared
    @State private var hover = false

    private var isVideo: Bool { ["mp4","mkv","webm","mov","m4v"].contains(entry.url.pathExtension.lowercased()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        if isVideo { VideoThumbnail(url: entry.url) } else {
                            ZStack { RoundedRectangle(cornerRadius: Theme.rSm).fill(Theme.surfaceHover)
                                Image(systemName: "waveform").font(.title).foregroundStyle(Theme.accent) }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.rSm).strokeBorder(selected ? Theme.accent : Theme.border, lineWidth: selected ? 2.5 : 1))
                    .overlay(alignment: .bottomLeading) {
                        let n = library.notes(for: entry).count
                        if n > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "note.text").font(.system(size: 8, weight: .bold))
                                Text("\(n)").font(.system(size: 9, weight: .bold))
                            }
                            .padding(.horizontal, 5).padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.55)))
                            .foregroundStyle(.white).padding(6)
                        }
                    }

                if selecting {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Theme.accent : .white)
                        .background(Circle().fill(.black.opacity(0.3))).padding(6)
                } else if hover {
                    HStack(spacing: 4) {
                        MiniAction(symbol: "scissors", help: AppSettings.shared.language == .malay ? "Klip" : "Clip") { clipEntry = entry }
                        MiniAction(symbol: "note.text", help: AppSettings.shared.language == .malay ? "Nota" : "Note") { noteEntry = entry }
                    }.padding(6)
                }
            }

            Text(entry.name)
                .font(.system(size: 11, weight: .medium)).lineLimit(1)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 5) {
                Text(formatLabel).font(.system(size: 9, weight: .bold, design: .monospaced))
                Text("·").foregroundStyle(Theme.border)
                Text(archiveDate).font(.system(size: 9))
            }
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            if let sourceLabel {
                Text(sourceLabel).font(.system(size: 9, weight: .medium)).foregroundStyle(Theme.accent).lineLimit(1)
            }
        }
        .scaleEffect(hover ? 1.02 : 1)
        .onHover { hover = $0 }.animation(Theme.bouncy, value: hover)
        .onTapGesture(count: 2) { playMediaInApp(entry.url) }
        .onTapGesture { onTap() }
        .contextMenu {
            Button(AppSettings.shared.language == .malay ? "Main" : "Play") { playMediaInApp(entry.url) }
            Button(AppSettings.shared.language == .malay ? "Klip / Sunting…" : "Clip / Edit…") { clipEntry = entry }
            Button(AppSettings.shared.language == .malay ? "Tambah Nota…" : "Add Note…") { noteEntry = entry }
            Button(AppSettings.shared.language == .malay ? "Gandakan" : "Duplicate") { library.copy(entry) }
            Button(AppSettings.shared.language == .malay ? "Tunjuk di Finder" : "Reveal in Finder") { library.revealInFinder(entry) }
            Divider()
            Button(AppSettings.shared.language == .malay ? "Pindah ke Sampah" : "Move to Trash", role: .destructive) { library.trash(entry) }
        }
    }

    private var record: DownloadItem? { DownloadManager.shared.record(forPath: entry.url.path) }
    private var formatLabel: String {
        let ext = entry.url.pathExtension.uppercased()
        if let note = record?.formatNote, !note.isEmpty { return "\(ext) · \(note)" }
        if let quality = record?.qualityLabel, !quality.isEmpty { return "\(ext) · \(quality)" }
        return ext.isEmpty ? "MEDIA" : ext
    }
    private var archiveDate: String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ms_MY"); formatter.dateFormat = "d MMM yyyy"
        return "Arkib \(formatter.string(from: record?.completedAt ?? entry.modified))"
    }
    private var sourceLabel: String? {
        guard let platform = record?.platform, platform != .generic else { return nil }
        return platform.label
    }
}

// MARK: - Player tab (built-in media player)

struct PlayerTabView: View {
    let search: String
    let requestedURL: URL?
    @ObservedObject private var library = LibraryStore.shared
    @State private var media: [LibraryEntry] = []
    @State private var index = 0
    @State private var player: AVPlayer?

    private var list: [LibraryEntry] {
        search.isEmpty ? media : media.filter { libraryEntryMatches($0, query: search) }
    }
    private var current: LibraryEntry? { list.indices.contains(index) ? list[index] : nil }

    @State private var showList = false

    var body: some View {
        // Player is the focus — the media list lives behind the list button.
        VStack(spacing: 16) {
            Group {
                if let player {
                    PlayerView(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: Theme.rMd).fill(Theme.surface)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(Image(systemName: "play.circle").font(.system(size: 48)).foregroundStyle(Theme.textSecondary))
                }
            }
            .frame(maxWidth: 900)

            if let c = current {
                Text(c.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
            }
            HStack(spacing: 18) {
                ctl("backward.fill") { step(-1) }
                ctl("play.fill") { player?.play() }
                ctl("pause.fill") { player?.pause() }
                ctl("forward.fill") { step(1) }
                ctl("trash") { if let c = current { library.trash(c); reload() } }
                ctl("list.bullet", badge: list.count) { showList.toggle() }
                    .popover(isPresented: $showList, arrowEdge: .top) {
                        MediaPickerPopover(videosOnly: false, currentPath: current?.url.path) { e in
                            media = library.allMedia()
                            if let i = list.firstIndex(where: { $0.id == e.id }) { index = i; load() }
                            showList = false
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40).padding(.top, 96).padding(.bottom, 100)
        .onAppear {
            reload()
            openRequestedMedia()
        }
        .onReceive(NotificationCenter.default.publisher(for: .musimPlayMedia)) { note in
            guard let url = note.userInfo?["url"] as? URL else { return }
            media = library.allMedia()
            if let i = media.firstIndex(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
                index = i
                load()
            }
        }
        .onChange(of: requestedURL) { _, url in
            guard url != nil else { return }
            openRequestedMedia()
        }
    }


    private func ctl(_ s: String, badge: Int = 0, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: s).font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44).background(Circle().fill(Theme.surface))
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1)).foregroundStyle(Theme.textPrimary)
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(4).background(Circle().fill(Theme.accent)).offset(x: 3, y: -3)
                    }
                }
        }
        .buttonStyle(.plain)
    }
    private func reload() { media = library.allMedia(); if index >= media.count { index = 0 }; load() }
    private func openRequestedMedia() {
        guard let url = requestedURL else { return }
        if let i = media.firstIndex(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            index = i
            load()
        }
    }
    /// Next/previous load the item but never auto-play — the user presses play.
    private func step(_ d: Int) { guard !list.isEmpty else { return }; index = (index + d + list.count) % list.count; load() }
    /// Loads the current item, always paused. Playback is only ever started by
    /// the explicit play button.
    private func load() {
        guard let c = current else { player = nil; return }
        player = AVPlayer(url: c.url)
    }
}

/// A self-contained media picker shown in a popover. It loads its own media on
/// appear (so it's never empty due to popover state-capture timing) and groups
/// items by their containing folder.
struct MediaPickerPopover: View {
    var videosOnly: Bool = false
    var currentPath: String? = nil
    let onPick: (LibraryEntry) -> Void
    @ObservedObject private var library = LibraryStore.shared
    @State private var media: [LibraryEntry] = []

    private var items: [LibraryEntry] {
        videosOnly ? media.filter { ["mp4","mkv","webm","mov","m4v"].contains($0.url.pathExtension.lowercased()) } : media
    }
    /// Group by containing folder name (root shows as the library name).
    private var groups: [(folder: String, items: [LibraryEntry])] {
        let root = library.root.standardizedFileURL.path
        let grouped = Dictionary(grouping: items) { e -> String in
            let parent = e.url.deletingLastPathComponent().standardizedFileURL.path
            return parent == root ? loc("nav.library") : e.url.deletingLastPathComponent().lastPathComponent
        }
        return grouped.map { ($0.key, $0.value.sorted { $0.modified > $1.modified }) }
            .sorted { $0.folder.localizedCaseInsensitiveCompare($1.folder) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(loc("lib.media")).font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "film").font(.system(size: 26)).foregroundStyle(.tertiary)
                    Text(AppSettings.shared.language == .malay ? "Tiada media lagi" : "No media yet")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }.frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4, pinnedViews: [.sectionHeaders]) {
                        ForEach(groups, id: \.folder) { group in
                            Section {
                                ForEach(group.items) { e in row(e) }
                            } header: {
                                HStack(spacing: 5) {
                                    Image(systemName: "folder.fill").font(.system(size: 9)).foregroundStyle(Theme.accent)
                                    Text(group.folder).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Theme.bgElevated.opacity(0.96))
                            }
                        }
                    }.padding(.horizontal, 8).padding(.bottom, 10)
                }
            }
        }
        .frame(width: 300, height: 380)
        .onAppear { media = library.allMedia() }
    }

    private func row(_ e: LibraryEntry) -> some View {
        let isCurrent = currentPath == e.url.path
        return Button { onPick(e) } label: {
            HStack(spacing: 8) {
                Image(systemName: isCurrent ? "play.fill" : "film").font(.caption2)
                    .foregroundStyle(isCurrent ? Theme.accent : Theme.textSecondary).frame(width: 16)
                Text(e.name).font(.system(size: 12)).lineLimit(1).foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(isCurrent ? Theme.accentSoft : Color.clear))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: - Editor tab (trim, ratio, resolution, speed, preview, export)

struct EditorTabView: View {
    @ObservedObject private var library = LibraryStore.shared
    @State private var media: [LibraryEntry] = []
    @State private var selected: LibraryEntry?
    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var currentTime: Double = 0
    @State private var speed: Double = 1.0
    @State private var aspect: LibraryStore.AspectRatio = .original
    @State private var cropX: Double = 0.5
    @State private var cropY: Double = 0.5
    @State private var videoAspect: CGFloat = 16 / 9
    @State private var maxHeight = 0   // 0 = original
    @State private var exporting = false
    @State private var message: String?

    private let heights = [0, 1080, 720, 480]
    @State private var showList = false

    private var videos: [LibraryEntry] {
        media.filter { ["mp4","mkv","webm","mov","m4v"].contains($0.url.pathExtension.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.below.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.accentSoft))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppSettings.shared.language == .malay ? "Editor Video" : "Video Editor")
                            .font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.textPrimary)
                        Text(selected?.name ?? (AppSettings.shared.language == .malay ? "Pilih video untuk mula bekerja" : "Choose a video to start working"))
                            .font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    }
                    Spacer()
                    Button { media = library.allMedia(); showList.toggle() } label: {
                        Label(AppSettings.shared.language == .malay ? "Buka media" : "Open media", systemImage: "film.stack")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(Theme.surface)).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showList, arrowEdge: .top) {
                        MediaPickerPopover(videosOnly: true, currentPath: selected?.url.path) { e in
                            select(e); showList = false
                        }
                    }
                }

            if selected == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.below.rectangle").font(.system(size: 44)).foregroundStyle(Theme.textSecondary.opacity(0.5))
                        Text(AppSettings.shared.language == .malay ? "Pilih video untuk potong, krop, dan laraskan kelajuan." : "Pick a video to trim, crop, and adjust speed.")
                            .font(.callout).foregroundStyle(Theme.textSecondary)
                        Button { showList = true } label: { Label(AppSettings.shared.language == .malay ? "Pilih video" : "Choose video", systemImage: "film") }
                            .buttonStyle(GlassButtonStyle())
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 14) {
                        editorPreview
                        if duration > 0, let selected {
                            ThumbnailTimelineView(url: selected.url, start: $start, end: $end, currentTime: $currentTime, total: duration) { t in
                                currentTime = t
                                player?.seek(to: CMTime(seconds: t, preferredTimescale: 600))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label(AppSettings.shared.language == .malay ? "Pelarasan" : "Adjustments", systemImage: "slider.horizontal.3")
                                    .font(.headline)
                                Spacer()
                                Text(AppSettings.shared.language == .malay ? "Eksport" : "Export")
                                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                            }
                            .foregroundStyle(Theme.textPrimary)
                            editControls
                            if let message { Text(message).font(.caption).foregroundStyle(Theme.textSecondary) }
                            Button { runExport() } label: {
                                if exporting { ProgressView().controlSize(.small) }
                                else { Label(AppSettings.shared.language == .malay ? "Eksport" : "Export", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                            }
                            .buttonStyle(ExpressiveButtonStyle()).disabled(exporting || end - start < 0.3)
                        }
                        .padding(2)
                    }
                    .frame(minWidth: 220, idealWidth: 270, maxWidth: 300)
                    .layoutPriority(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 28).padding(.top, 96).padding(.bottom, 100)
        .background(Theme.bg)
        .onAppear { media = library.allMedia() }
        .onChange(of: speed) { _, value in
            if player?.timeControlStatus == .playing { player?.rate = Float(value) }
        }
    }

    @ViewBuilder
    private var editorPreview: some View {
        if let player {
            VStack(spacing: 0) {
                CropPreviewView(player: player, sourceAspect: videoAspect, cropAspect: aspect.ratio,
                                cropX: $cropX, cropY: $cropY)
                    .frame(maxWidth: .infinity, minHeight: 250, maxHeight: 470)
                HStack(spacing: 10) {
                    Button {
                        if player.timeControlStatus == .playing { player.pause() }
                        else { player.playImmediately(atRate: Float(speed)) }
                    } label: {
                        Image(systemName: player.timeControlStatus == .playing ? "pause.fill" : "play.fill")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    Text(tstr(currentTime)).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(tstr(duration)).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.surface.opacity(0.7))
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        }
    }

    private var editControls: some View {
        VStack(spacing: 12) {
            pickerRow(AppSettings.shared.language == .malay ? "Kelajuan" : "Speed") {
                Picker("", selection: $speed) {
                    Text("0.5×").tag(0.5); Text("1×").tag(1.0); Text("1.5×").tag(1.5); Text("2×").tag(2.0)
                }.pickerStyle(.segmented).labelsHidden()
            }
            pickerRow(loc("common.format")) {
                Picker("", selection: $aspect) {
                    ForEach(LibraryStore.AspectRatio.allCases) { Text($0 == .original ? (AppSettings.shared.language == .malay ? "Asal" : "Original") : $0.rawValue).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            pickerRow(AppSettings.shared.language == .malay ? "Resolusi" : "Resolution") {
                Picker("", selection: $maxHeight) {
                    ForEach(heights, id: \.self) { Text($0 == 0 ? (AppSettings.shared.language == .malay ? "Asal" : "Original") : "\($0)p").tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            if aspect != .original {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Label(AppSettings.shared.language == .malay ? "Posisi crop" : "Crop position", systemImage: "move.3d")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(AppSettings.shared.language == .malay ? "Seret video" : "Drag video")
                            .font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                    cropSlider(label: AppSettings.shared.language == .malay ? "Kiri / Kanan" : "Left / Right", value: $cropX)
                    cropSlider(label: AppSettings.shared.language == .malay ? "Atas / Bawah" : "Up / Down", value: $cropY)
                }
                .padding(12)
                .glassCard(radius: Theme.rMd)
            }
        }
        .padding(14).glassCard(radius: Theme.rMd)
    }

    private func pickerRow<C: View>(_ label: String, @ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
                .frame(width: 78, alignment: .leading)
            c().frame(maxWidth: .infinity)
        }
    }

    private func cropSlider(label: String, value: Binding<Double>) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption2).foregroundStyle(Theme.textSecondary).frame(width: 78, alignment: .leading)
            Slider(value: value, in: 0...1)
        }
    }

    private func select(_ e: LibraryEntry) {
        selected = e; message = nil; speed = 1; aspect = .original; maxHeight = 0; cropX = 0.5; cropY = 0.5; currentTime = 0
        player = AVPlayer(url: e.url)
        player?.rate = Float(speed)
        Task {
            let asset = AVURLAsset(url: e.url)
            let d = (try? await asset.load(.duration).seconds) ?? 0
            let tracks = try? await asset.loadTracks(withMediaType: .video)
            let natural = (try? await tracks?.first?.load(.naturalSize)) ?? CGSize(width: 16, height: 9)
            let transform = (try? await tracks?.first?.load(.preferredTransform)) ?? .identity
            let oriented = natural.applying(transform)
            let a = abs(oriented.width / max(oriented.height, 1))
            await MainActor.run { duration = d.isFinite ? d : 0; start = 0; end = duration; currentTime = 0; videoAspect = a.isFinite && a > 0 ? a : 16 / 9 }
        }
    }

    private func runExport() {
        guard let e = selected else { return }
        exporting = true; message = nil
        let opts = LibraryStore.EditOptions(start: start, end: end, speed: speed, aspect: aspect,
                                            maxHeight: maxHeight == 0 ? nil : maxHeight,
                                            cropX: cropX, cropY: cropY)
        library.exportEdit(of: e, options: opts) { result in
            exporting = false
            switch result {
            case .success(let url): message = "Saved: \(url.lastPathComponent)"; media = library.allMedia()
            case .failure(let err): message = "Failed: \(err.localizedDescription)"
            }
        }
    }

    private func tstr(_ t: Double) -> String { let s = max(0, Int(t)); return String(format: "%d:%02d", s/60, s%60) }
}

/// Cropped editor preview. Dragging the image changes the crop focus that is
/// sent to the export pipeline, so the viewer and exported file stay aligned.
struct CropPreviewView: View {
    let player: AVPlayer
    let sourceAspect: CGFloat
    let cropAspect: CGFloat?
    @Binding var cropX: Double
    @Binding var cropY: Double
    @State private var dragStartX = 0.5
    @State private var dragStartY = 0.5

    var body: some View {
        GeometryReader { geo in
            let sourceFit = fittedSource(in: geo.size)
            let scale = max(geo.size.width / max(sourceFit.width, 1), geo.size.height / max(sourceFit.height, 1))
            let rendered = CGSize(width: sourceFit.width * scale, height: sourceFit.height * scale)
            let overflowX = max(0, rendered.width - geo.size.width)
            let overflowY = max(0, rendered.height - geo.size.height)

            ZStack {
                Color.black
                PlayerView(player: player)
                    .frame(width: sourceFit.width, height: sourceFit.height)
                    .scaleEffect(scale)
                    .offset(x: (0.5 - cropX) * overflowX, y: (0.5 - cropY) * overflowY)
                if cropAspect != nil {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                        .padding(8)
                        .overlay(alignment: .bottomLeading) {
                            Label(AppSettings.shared.language == .malay ? "Seret untuk ubah crop" : "Drag to adjust crop", systemImage: "hand.draw")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background(Capsule().fill(.black.opacity(0.65)))
                                .foregroundStyle(.white)
                                .padding(14)
                        }
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        guard cropAspect != nil else { return }
                        cropX = min(1, max(0, dragStartX - Double(gesture.translation.width / max(overflowX, 1))))
                        cropY = min(1, max(0, dragStartY - Double(gesture.translation.height / max(overflowY, 1))))
                    }
                    .onEnded { _ in
                        dragStartX = cropX
                        dragStartY = cropY
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous))
        }
        .aspectRatio(cropAspect ?? sourceAspect, contentMode: .fit)
        .background(Color.black)
    }

    private func fittedSource(in container: CGSize) -> CGSize {
        guard container.width > 0, container.height > 0, sourceAspect > 0 else { return container }
        if container.width / container.height > sourceAspect {
            return CGSize(width: container.height * sourceAspect, height: container.height)
        }
        return CGSize(width: container.width, height: container.width / sourceAspect)
    }
}

/// Filmstrip timeline with generated thumbnails, a movable playhead, and trim handles.
struct ThumbnailTimelineView: View {
    let url: URL
    @Binding var start: Double
    @Binding var end: Double
    @Binding var currentTime: Double
    let total: Double
    var onScrub: (Double) -> Void

    @State private var thumbnails: [NSImage] = []
    private let count = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(AppSettings.shared.language == .malay ? "Garis masa" : "Timeline", systemImage: "film")
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(timeString(start)) – \(timeString(end))")
                    .font(.caption.monospacedDigit()).foregroundStyle(Theme.accent)
            }

            GeometryReader { geo in
                let width = max(1, geo.size.width)
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, image in
                            Image(nsImage: image).resizable().scaledToFill()
                                .frame(width: max(1, (width - CGFloat(count - 1) * 2) / CGFloat(count)), height: 72)
                                .clipped()
                        }
                        if thumbnails.isEmpty {
                            ForEach(0..<count, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 3).fill(Theme.surfaceHover)
                                    .frame(height: 72)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    trimShade(width: width, from: 0, to: start / total)
                    trimShade(width: width, from: end / total, to: 1)

                    Rectangle().fill(Theme.accent).frame(width: 2, height: 84)
                        .offset(x: CGFloat(currentTime / total) * width - 1)
                        .shadow(color: Theme.accent.opacity(0.7), radius: 4)

                    trimHandle(value: start, width: width, leading: true)
                    trimHandle(value: end, width: width, leading: false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                    let t = min(total, max(0, Double(gesture.location.x / width) * total))
                    currentTime = t
                    onScrub(t)
                })
            }
            .frame(height: 84)

            HStack {
                Text(timeString(0))
                Spacer()
                Text(timeString(total))
            }
            .font(.caption2.monospacedDigit()).foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .glassCard(radius: Theme.rMd)
        .task(id: url) { await loadThumbnails() }
    }

    private func trimShade(width: CGFloat, from: Double, to: Double) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.58))
            .frame(width: max(0, CGFloat(to - from) * width), height: 72)
            .offset(x: CGFloat(from) * width)
            .allowsHitTesting(false)
    }

    private func trimHandle(value: Double, width: CGFloat, leading: Bool) -> some View {
        VStack(spacing: 0) {
            Capsule().fill(Theme.accent).frame(width: 5, height: 14)
            Capsule().fill(Theme.accent).frame(width: 5, height: 70)
        }
        .frame(width: 18, height: 84)
        .contentShape(Rectangle())
        .offset(x: CGFloat(value / total) * width - 9)
        .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
            let t = min(total, max(0, Double(gesture.location.x / width) * total))
            if leading {
                start = min(t, end - 0.5)
                currentTime = start
                onScrub(start)
            } else {
                end = max(t, start + 0.5)
                currentTime = end
                onScrub(end)
            }
        })
    }

    private func loadThumbnails() async {
        let asset = AVURLAsset(url: url)
        let duration = (try? await asset.load(.duration).seconds) ?? total
        guard duration.isFinite, duration > 0 else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 220, height: 140)
        var loaded: [NSImage] = []
        for index in 0..<count {
            let second = duration * (Double(index) + 0.5) / Double(count)
            if let cg = try? await generator.image(at: CMTime(seconds: second, preferredTimescale: 600)).image {
                loaded.append(NSImage(cgImage: cg, size: .zero))
            }
        }
        await MainActor.run { thumbnails = loaded }
    }

    private func timeString(_ time: Double) -> String {
        let seconds = max(0, Int(time))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Subtle dotted background so the canvas feels like a board.
struct DotGridBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 28
            var y: CGFloat = step
            while y < size.height {
                var x: CGFloat = step
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                             with: .color(.primary.opacity(0.06)))
                    x += step
                }
                y += step
            }
        }
    }
}

// MARK: - Canvas card (draggable)

struct CanvasCard: View {
    let entry: LibraryEntry
    let basePosition: CGPoint
    var organized: Bool = false
    @Binding var clipEntry: LibraryEntry?
    @Binding var noteEntry: LibraryEntry?
    @Binding var dragOverFolder: String?
    @Binding var selection: Set<String>
    let selecting: Bool
    let allEntries: [LibraryEntry]
    let index: Int
    let canvasWidth: CGFloat

    @ObservedObject private var library = LibraryStore.shared
    @State private var dragOffset: CGSize = .zero
    @State private var dragging = false
    @State private var hover = false
    @State private var renaming = false
    @State private var newName = ""
    @FocusState private var renameFocused: Bool

    private var noteList: [StickyNote] { library.notes(for: entry) }
    private var isDropTarget: Bool { dragOverFolder == entry.id }
    private var isSelected: Bool { selection.contains(entry.id) }
    private var currentPos: CGPoint {
        CGPoint(x: basePosition.x + dragOffset.width, y: basePosition.y + dragOffset.height)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                thumbnail
                    .frame(width: LibraryView.cardSize.width - 20, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                if hover && entry.isMedia {
                    playOverlay
                }
            }

            if renaming {
                TextField("", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .focused($renameFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { renaming = false }
            } else {
                Text(entry.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .onTapGesture(count: 2) { beginRename() }
            }

            HStack {
                Text(entry.isFolder ? folderInfo : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                if hover && !dragging {
                    HStack(spacing: 3) {
                        if entry.isMedia { MiniAction(symbol: "scissors", help: AppSettings.shared.language == .malay ? "Klip" : "Clip") { clipEntry = entry } }
                        MiniAction(symbol: "note.text", help: AppSettings.shared.language == .malay ? "Nota" : "Note") { noteEntry = entry }
                        MiniAction(symbol: "magnifyingglass", help: "Finder") { library.revealInFinder(entry) }
                    }
                }
            }
            .frame(height: 18)
        }
        .padding(10)
        .frame(width: LibraryView.cardSize.width)
        .glassCard(radius: Theme.rMd, glow: dragging, glowColor: Theme.accent)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous)
                .strokeBorder(isDropTarget ? AnyShapeStyle(Theme.accentGradient) :
                              isSelected ? AnyShapeStyle(Theme.accent) :
                              dragging ? AnyShapeStyle(Theme.accent.opacity(0.5)) : AnyShapeStyle(.clear),
                              lineWidth: isDropTarget || isSelected ? 2.5 : 1.5)
        )
        .overlay(alignment: .topLeading) {
            if selecting && !entry.isFolder && entry.isMedia {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? Theme.accent : .white)
                    .background(Circle().fill(.black.opacity(0.32)))
                    .padding(8)
            }
        }
        // sticky notes pinned to the card (fanned, up to 5)
        .overlay(alignment: .topTrailing) {
            if !noteList.isEmpty {
                ZStack {
                    ForEach(Array(noteList.prefix(5).enumerated()), id: \.element.id) { i, n in
                        BigStickyNote(note: n)
                            .scaleEffect(0.62)
                            .rotationEffect(.degrees(Double(i) * 5 - 4))
                            .offset(x: 24 + CGFloat(i) * 7, y: -24 + CGFloat(i) * 6)
                            .zIndex(Double(i))
                    }
                }
                .onTapGesture { noteEntry = entry }
            }
        }
        .scaleEffect(dragging ? 1.06 : hover ? 1.02 : 1)
        .rotationEffect(.degrees(dragging ? 1.5 : 0))
        .position(currentPos)
        .zIndex(dragging ? 100 : !noteList.isEmpty ? 2 : 1)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragging)
        .gesture(dragGesture)
        .contextMenu { contextItems }
        .onTapGesture {
            if selecting && !entry.isFolder && entry.isMedia {
                toggleSelection()
            }
        }
        .onTapGesture(count: 2) {
            guard !selecting else { return }
            if entry.isFolder { withAnimation { library.open(folder: entry.url) } }
            else { playMediaInApp(entry.url) }
        }
    }

    private var folderInfo: String {
        let count = (try? FileManager.default.contentsOfDirectory(atPath: entry.url.path).filter { !$0.hasPrefix(".") }.count) ?? 0
        return AppSettings.shared.language == .malay ? "\(count) item" : "\(count) item\(count == 1 ? "" : "s")"
    }

    // MARK: Drag to arrange / drop into folders

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { g in
                guard !entry.isFolder else {
                    dragging = true
                    dragOffset = g.translation
                    return
                }
                dragging = true
                dragOffset = g.translation
                dragOverFolder = folderUnderCard()?.id
            }
            .onEnded { _ in
                dragging = false
                if !entry.isFolder, let target = folderUnderCard() {
                    dragOverFolder = nil
                    dragOffset = .zero
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        library.move(paths: dragMediaPaths, into: target)
                        selection.subtract(dragMediaPaths)
                    }
                } else {
                    dragOverFolder = nil
                    let final = currentPos
                    dragOffset = .zero
                    library.setPosition(clamp(final), for: entry)
                }
            }
    }

    private func folderUnderCard() -> LibraryEntry? {
        for (i, other) in allEntries.enumerated() where other.isFolder && other.id != entry.id {
            let p = visualPosition(for: i, entry: other)
            if abs(p.x - currentPos.x) < LibraryView.cardSize.width * 0.7,
               abs(p.y - currentPos.y) < LibraryView.cardSize.height * 0.7 {
                return other
            }
        }
        return nil
    }

    private var dragMediaPaths: [String] {
        let selectedMedia = allEntries
            .filter { selection.contains($0.id) && !$0.isFolder && $0.isMedia }
            .map(\.url.path)
        if selectedMedia.contains(entry.url.path) { return selectedMedia }
        return [entry.url.path]
    }

    private func visualPosition(for index: Int, entry: LibraryEntry) -> CGPoint {
        if organized {
            let perRow = max(1, Int((canvasWidth - 120) / 230))
            let col = index % perRow
            let row = index / perRow
            return CGPoint(x: 150 + CGFloat(col) * 230, y: 220 + CGFloat(row) * 210)
        }
        return library.position(for: entry, index: index, canvasWidth: canvasWidth)
    }

    private func toggleSelection() {
        if selection.contains(entry.id) { selection.remove(entry.id) }
        else { selection.insert(entry.id) }
    }

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 110), 2600 - 110), y: min(max(p.y, 100), 1800 - 100))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if entry.isFolder {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.blue.opacity(isDropTarget ? 0.35 : 0.18), .blue.opacity(0.08)],
                                         startPoint: .top, endPoint: .bottom))
                Image(systemName: isDropTarget ? "folder.fill.badge.plus" : "folder.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue.opacity(0.8))
                    .scaleEffect(isDropTarget ? 1.15 : 1)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTarget)
        } else if entry.isMedia && ["mp4", "mkv", "webm", "mov", "m4v"].contains(entry.url.pathExtension.lowercased()) {
            VideoThumbnail(url: entry.url)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LinearGradient(colors: [.purple.opacity(0.18), .purple.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                Image(systemName: "waveform").font(.system(size: 30)).foregroundStyle(.purple.opacity(0.75))
            }
        }
    }

    private var playOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.black.opacity(0.25))
            Image(systemName: "play.circle.fill")
                .font(.system(size: 32)).foregroundStyle(.white).shadow(radius: 4)
        }
        .frame(width: LibraryView.cardSize.width - 20, height: 100)
        .onTapGesture { playMediaInApp(entry.url) }
        .transition(.opacity)
    }

    @ViewBuilder
    private var contextItems: some View {
        if entry.isMedia {
            Button(AppSettings.shared.language == .malay ? "Main" : "Play") { playMediaInApp(entry.url) }
            Button(AppSettings.shared.language == .malay ? "Klip / Sunting…" : "Clip / Edit…") { clipEntry = entry }
        }
        if entry.isFolder { Button(AppSettings.shared.language == .malay ? "Buka" : "Open") { library.open(folder: entry.url) } }
        Button(AppSettings.shared.language == .malay ? "Tukar nama" : "Rename") { beginRename() }
        Button(noteList.isEmpty ? (AppSettings.shared.language == .malay ? "Tambah Nota Lekat…" : "Add Sticky Note…")
                                : (AppSettings.shared.language == .malay ? "Nota Lekat…" : "Sticky Notes…")) { noteEntry = entry }
        Button(AppSettings.shared.language == .malay ? "Tunjuk di Finder" : "Reveal in Finder") { library.revealInFinder(entry) }
        Divider()
        Button(AppSettings.shared.language == .malay ? "Pindah ke Sampah" : "Move to Trash", role: .destructive) { withAnimation { library.trash(entry) } }
    }

    private func beginRename() {
        newName = entry.name
        renaming = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { renameFocused = true }
    }
    private func commitRename() {
        renaming = false
        library.rename(entry, to: newName)
    }
}

/// Sticky note that hangs off a card — dynamic size, renders rich text.
struct BigStickyNote: View {
    let note: StickyNote
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if note.rtf != nil {
                Text(AttributedString(note.attributed))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black.opacity(0.82))
                    .padding(10)
                Spacer(minLength: 0)
            } else {
                Text(note.text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.black.opacity(0.82))
                    .padding(10)
                Spacer(minLength: 0)
            }
        }
        .frame(width: note.size.dims.width, height: note.size.dims.height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
        )
        .rotationEffect(.degrees(3))
    }

    private var color: Color { NoteColors.fill(note.color) }
}

/// First-frame thumbnail for local videos.
struct VideoThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.gray.opacity(0.15))
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film").font(.title2).foregroundStyle(.quaternary)
            }
        }
        .task(id: url) {
            let asset = AVURLAsset(url: url)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 480, height: 480)
            if let cg = try? await gen.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image {
                image = NSImage(cgImage: cg, size: .zero)
            }
        }
    }
}

// MARK: - Sticky note editor (multiple notes per item, rich text, sizes)

struct NoteEditorView: View {
    let entry: LibraryEntry
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = LibraryStore.shared
    @State private var editing: StickyNote?      // the note being edited, if any
    private var my: Bool { AppSettings.shared.language == .malay }

    private var list: [StickyNote] { library.notes(for: entry) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(my ? "Nota Lekat" : "Sticky Notes").font(.title3.bold())
                    Text(entry.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Text("\(list.count)/\(LibraryStore.maxNotesPerItem)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }

            if let editing {
                NoteComposer(note: editing, onSave: { n in
                    library.upsertNote(n, for: entry); self.editing = nil
                }, onCancel: { self.editing = nil })
            } else {
                // Notes gallery
                if list.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "note.text").font(.system(size: 34)).foregroundStyle(.tertiary)
                        Text(my ? "Belum ada nota" : "No notes yet").font(.callout).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ScrollView {
                        FlowLayout(spacing: 10) {
                            ForEach(list) { n in
                                NotePreview(note: n)
                                    .onTapGesture { editing = n }
                                    .contextMenu {
                                        Button(my ? "Sunting" : "Edit") { editing = n }
                                        Button(my ? "Padam" : "Delete", role: .destructive) {
                                            library.removeNote(id: n.id, for: entry)
                                        }
                                    }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 260)
                }

                Button {
                    editing = StickyNote()
                } label: {
                    Label(my ? "Tambah nota" : "Add note", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ExpressiveButtonStyle())
                .disabled(list.count >= LibraryStore.maxNotesPerItem)
            }
        }
        .padding(22)
        .frame(width: 460)
    }
}

/// A small non-interactive preview of a saved note in the gallery.
struct NotePreview: View {
    let note: StickyNote
    var body: some View {
        Text(AttributedString(note.attributed))
            .font(.system(size: 10, weight: .medium)).foregroundStyle(.black.opacity(0.82))
            .padding(8)
            .frame(width: note.size.dims.width * 0.8, height: note.size.dims.height * 0.8, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 4).fill(NoteColors.fill(note.color))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2))
    }
}

/// Compose / edit a single note: rich text + size + colour.
struct NoteComposer: View {
    @State var note: StickyNote
    var onSave: (StickyNote) -> Void
    var onCancel: () -> Void
    @State private var attributed: NSAttributedString
    private var my: Bool { AppSettings.shared.language == .malay }

    init(note: StickyNote, onSave: @escaping (StickyNote) -> Void, onCancel: @escaping () -> Void) {
        _note = State(initialValue: note)
        self.onSave = onSave; self.onCancel = onCancel
        _attributed = State(initialValue: note.attributed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RichTextEditor(text: $attributed)
                .frame(height: 150)
                .background(RoundedRectangle(cornerRadius: 10).fill(NoteColors.fill(note.color).opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))

            HStack(spacing: 8) {
                Text(my ? "Saiz" : "Size").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                ForEach(NoteSize.allCases) { s in
                    Button { note.size = s } label: {
                        Image(systemName: s.symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 30, height: 26)
                            .background(RoundedRectangle(cornerRadius: 7).fill(note.size == s ? Theme.accent : Theme.surface))
                            .foregroundStyle(note.size == s ? .white : Theme.textSecondary)
                    }.buttonStyle(.plain).help(s.label)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                ForEach(NoteColors.names, id: \.self) { c in
                    Circle().fill(NoteColors.fill(c)).frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(.primary.opacity(note.color == c ? 0.7 : 0.15), lineWidth: 2))
                        .onTapGesture { withAnimation { note.color = c } }
                }
                Spacer()
                Button(my ? "Batal" : "Cancel") { onCancel() }.buttonStyle(GlassButtonStyle())
                Button(my ? "Simpan" : "Save") { save() }
                    .buttonStyle(ExpressiveButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }
    }

    private func save() {
        var n = note
        n.text = attributed.string
        n.rtf = try? attributed.data(from: NSRange(location: 0, length: attributed.length),
                                     documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        guard !n.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { onCancel(); return }
        onSave(n)
    }
}

/// Browse every sticky note across the library, with the item it links to.
struct NotesBrowser: View {
    var onOpen: (LibraryEntry) -> Void
    @ObservedObject private var library = LibraryStore.shared
    @State private var query = ""
    private var my: Bool { AppSettings.shared.language == .malay }

    private var all: [(entry: LibraryEntry, note: StickyNote)] {
        let items = library.allNotes()
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.entry.name.localizedCaseInsensitiveContains(query) || $0.note.text.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(my ? "Semua Nota" : "All Notes").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(all.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }.padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                TextField(my ? "Cari nota" : "Search notes", text: $query).textFieldStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Theme.surface)).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
            .padding(.horizontal, 14).padding(.bottom, 8)
            Divider()

            if all.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text").font(.system(size: 30)).foregroundStyle(.tertiary)
                    Text(my ? "Tiada nota lagi" : "No notes yet").font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 140)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(all.enumerated()), id: \.offset) { _, pair in
                            Button { onOpen(pair.entry) } label: {
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 4).fill(NoteColors.fill(pair.note.color)).frame(width: 26, height: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pair.note.text.isEmpty ? "—" : pair.note.text)
                                            .font(.system(size: 12, weight: .medium)).lineLimit(1).foregroundStyle(Theme.textPrimary)
                                        HStack(spacing: 4) {
                                            Image(systemName: pair.entry.isFolder ? "folder.fill" : "film").font(.system(size: 9))
                                            Text(pair.entry.name).font(.system(size: 10)).lineLimit(1)
                                        }.foregroundStyle(Theme.textSecondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.surface.opacity(0.5)))
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.padding(12)
                }
            }
        }
        .frame(width: 330, height: 420)
    }
}

/// Shared sticky-note palette.
enum NoteColors {
    static let names = ["yellow", "pink", "blue", "green", "orange", "purple", "teal"]
    static func fill(_ name: String) -> Color {
        switch name {
        case "pink": return Color(red: 1, green: 0.75, blue: 0.85)
        case "blue": return Color(red: 0.70, green: 0.87, blue: 1)
        case "green": return Color(red: 0.75, green: 0.95, blue: 0.75)
        case "orange": return Color(red: 1, green: 0.82, blue: 0.60)
        case "purple": return Color(red: 0.83, green: 0.76, blue: 1)
        case "teal": return Color(red: 0.68, green: 0.93, blue: 0.90)
        default: return Color(red: 1, green: 0.92, blue: 0.5)
        }
    }
}

// MARK: - Clip editor (trim/export — the video-editing tool)

struct ClipEditorView: View {
    let entry: LibraryEntry
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = LibraryStore.shared
    @State private var player: AVPlayer?
    @State private var duration: Double = 0
    @State private var start: Double = 0
    @State private var end: Double = 0
    @State private var exporting = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("\(AppSettings.shared.language == .malay ? "Klip" : "Clip") — \(entry.name)").font(.headline).lineLimit(1)

            if let player {
                PlayerView(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if duration > 0 {
                VStack(spacing: 10) {
                    RangeSliderView(start: $start, end: $end, total: duration) { t in
                        player?.seek(to: CMTime(seconds: t, preferredTimescale: 600))
                    }
                    HStack {
                        Label(timeString(start), systemImage: "backward.end")
                        Spacer()
                        Text("\(AppSettings.shared.language == .malay ? "Panjang" : "Length"): \(timeString(end - start))").foregroundStyle(.secondary)
                        Spacer()
                        Label(timeString(end), systemImage: "forward.end")
                    }
                    .font(.caption.monospacedDigit())
                }
            }

            if let message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button(AppSettings.shared.language == .malay ? "Batal" : "Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    exporting = true
                    library.exportClip(of: entry, start: start, end: end) { result in
                        exporting = false
                        switch result {
                        case .success(let url): message = "\(AppSettings.shared.language == .malay ? "Disimpan" : "Saved"): \(url.lastPathComponent)"
                        case .failure(let err): message = "\(AppSettings.shared.language == .malay ? "Gagal" : "Failed"): \(err.localizedDescription)"
                        }
                    }
                } label: {
                    if exporting { ProgressView().controlSize(.small) }
                    else { Label(AppSettings.shared.language == .malay ? "Eksport Klip" : "Export Clip", systemImage: "scissors") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(exporting || end - start < 0.5)
            }
        }
        .padding(24)
        .frame(width: 620)
        .task {
            let asset = AVURLAsset(url: entry.url)
            player = AVPlayer(url: entry.url)
            if let d = try? await asset.load(.duration).seconds, d.isFinite {
                duration = d
                end = d
            }
        }
        .onDisappear { player?.pause() }
    }

    private func timeString(_ t: Double) -> String {
        let s = max(0, Int(t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Simple two-handle range slider for trimming.
struct RangeSliderView: View {
    @Binding var start: Double
    @Binding var end: Double
    let total: Double
    var onScrub: (Double) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary).frame(height: 6)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(0, CGFloat((end - start) / total) * w), height: 6)
                    .offset(x: CGFloat(start / total) * w)
                handle(at: start, in: w) { start = min(max(0, $0), end - 0.5); onScrub(start) }
                handle(at: end, in: w) { end = max(min(total, $0), start + 0.5); onScrub(end) }
            }
        }
        .frame(height: 22)
    }

    private func handle(at value: Double, in width: CGFloat, update: @escaping (Double) -> Void) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 18, height: 18)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .offset(x: CGFloat(value / total) * width - 9)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    update(Double(g.location.x / width) * total)
                }
            )
    }
}
