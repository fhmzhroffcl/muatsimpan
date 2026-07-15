import SwiftUI
import AppKit

/// Archive panel: greeting, a single paste-and-save bar, platform icon row,
/// inline options, the active queue, and recently-finished items (kept in place,
/// faded) so the activity panel is free to show pure history.
struct DownloadPanel: View {
    var onOpenActivity: () -> Void = {}
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var ytdlp = YtDlpManager.shared
    @ObservedObject private var greetings = GreetingEngine.shared
    @State private var input = ""
    @State private var detectedLinks: [String] = []
    @State private var pending: [PendingDownload] = []
    @State private var fetchTask: Task<Void, Never>?
    @State private var showLocationSheet = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    archiveIntro
                    downloadBar
                    if let err = ytdlp.installError { errorBanner(err) }
                    fetchingIndicator
                    pendingSection
                    queueList
                }
                .padding(24)
                .padding(.bottom, 60)
            }
            .scrollContentBackground(.hidden)

            ActivityDockLabel(onOpen: onOpenActivity)
                .padding(.bottom, 16)
        }
        .background(Theme.bg)
        .sheet(isPresented: $showLocationSheet) {
            SaveLocationSheet(onClose: { showLocationSheet = false })
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetings.current)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .id(greetings.current)
                    .transition(.push(from: .bottom).combined(with: .opacity))
                    .onTapGesture { greetings.rotate() }
                Text(settings.language == .malay ? "Tambah media ke arkib anda" : "Add media to your archive")
                    .font(.callout).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .animation(Theme.expressive, value: greetings.current)
        .padding(.top, 34)
    }

    private var archiveIntro: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42).background(Circle().fill(Theme.accentSoft))
            VStack(alignment: .leading, spacing: 4) {
                Text("Simpan ke arkib").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text("Tambah media ke simpanan peribadi anda. Fail disimpan terus di peranti sendiri.")
                    .font(.caption).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                Button { showLocationSheet = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill").font(.caption2).foregroundStyle(Theme.accent)
                        Text(settings.downloadPath).font(.caption2.monospaced()).foregroundStyle(Theme.textSecondary).lineLimit(1).truncationMode(.middle)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(settings.language == .malay ? "Tukar lokasi simpanan" : "Change save location")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: 680, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous).fill(Theme.surface.opacity(0.58)))
        .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    // MARK: Archive bar (paste → auto-fetch → save)

    private var downloadBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(detectedLinks.isEmpty ? Theme.textSecondary : Theme.accent)

            TextField(loc("dl.placeholder"), text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...8)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary)
                .focused($inputFocused)
                .onChange(of: input) { _, v in
                    detectedLinks = Platform.extractLinks(from: v)
                    scheduleAutoFetch()
                }
                .onSubmit(fetchNow)

            Button(action: fetchNow) {
                Label(loc("dl.fetch"), systemImage: "archivebox.fill")
            }
            .buttonStyle(ExpressiveButtonStyle())
            .help(detectedLinks.isEmpty ? (settings.language == .malay ? "Semak pautan daripada papan klip" : "Check clipboard link") : loc("dl.fetch"))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous)
                .strokeBorder(inputFocused ? Theme.accent.opacity(0.6) : Theme.border, lineWidth: 1)
        )
        .frame(maxWidth: 680)
        .animation(.easeOut(duration: 0.15), value: inputFocused)
    }

    /// Debounced auto-fetch when a pasted/typed link settles.
    private func scheduleAutoFetch() {
        fetchTask?.cancel()
        guard !detectedLinks.isEmpty, ytdlp.isReady else { return }
        fetchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if Task.isCancelled { return }
            await MainActor.run { fetchDetected() }
        }
    }

    /// Fetch button: if nothing typed, pull the clipboard first.
    private func fetchNow() {
        if detectedLinks.isEmpty {
            if let clip = NSPasteboard.general.string(forType: .string) {
                let links = Platform.extractLinks(from: clip)
                if !links.isEmpty { input = clip; detectedLinks = links }
            }
        }
        fetchDetected()
    }

    private func fetchDetected() {
        guard !detectedLinks.isEmpty, ytdlp.isReady else { return }
        let existing = Set(pending.map(\.url))
        let fresh = detectedLinks.filter { !existing.contains($0) }.map { PendingDownload(url: $0, type: .video) }
        guard !fresh.isEmpty else { return }
        withAnimation(Theme.smooth) { pending.append(contentsOf: fresh) }
        input = ""; detectedLinks = []
        for p in fresh {
            Task {
                let result = await MediaProber.probe(url: p.url,
                    settings: (settings.usesCookies ? settings.resolvedCookieBrowser : "none", settings.proxy))
                await MainActor.run {
                    // Reassign `pending` so the fetching indicator / card list
                    // recompute now that this item has resolved.
                    withAnimation(Theme.smooth) {
                        switch result {
                        case .success(let probe): p.probe = probe
                        case .failure(let err): p.error = err.message
                        }
                        pending = pending
                    }
                }
            }
        }
    }

    // MARK: Live fetching indicator (replaces the static platform row)

    /// While links are being checked, show a neutral archive status.
    @ViewBuilder private var fetchingIndicator: some View {
        let probing = pending.filter { $0.probe == nil && $0.error == nil }
        if !probing.isEmpty {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(loc("dl.fetchingFrom"))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textSecondary)
                Text("\(probing.count) item").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.accent)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func orderedPlatforms(_ items: [PendingDownload]) -> [Platform] {
        var seen = Set<Platform>(); var out: [Platform] = []
        for i in items where !seen.contains(i.platform) { seen.insert(i.platform); out.append(i.platform) }
        return out
    }

    private func brandChip(_ p: Platform) -> some View {
        let tint = BrandColors.color(p.label)
        return HStack(spacing: 4) {
            Image(systemName: p.symbol).font(.system(size: 9, weight: .bold))
            Text(p == .generic ? "Web" : p.label).font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.18)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1))
        .foregroundStyle(tint)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(msg).font(.callout).foregroundStyle(Theme.textPrimary)
            Spacer()
            Button(loc("common.retry")) { Task { await ytdlp.install() } }.buttonStyle(GlassButtonStyle())
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).fill(.orange.opacity(0.12)))
    }

    // MARK: Pending options

    @ViewBuilder private var pendingSection: some View {
        // Only show a card once the link has resolved (probe or error) — while
        // it's still probing it lives in the fetching indicator above.
        let resolved = pending.filter { $0.probe != nil || $0.error != nil }
        if !resolved.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(loc("dl.ready"), action: { withAnimation(Theme.bouncy) { pending.removeAll() } })
                ForEach(resolved) { p in
                    PendingCard(pending: p,
                                onRemove: { withAnimation(Theme.bouncy) { pending.removeAll { $0.id == p.id } } },
                                onDownload: { downloadOne(p) })
                        .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity),
                                                removal: .opacity.combined(with: .scale(scale: 0.92))))
                }
                if pending.count > 1 {
                    Button { downloadAll() } label: {
                        Label("\(loc("dl.downloadAll")) (\(pending.count))", systemImage: "archivebox.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ExpressiveButtonStyle())
                    .disabled(!pending.contains { $0.probe != nil })
                }
            }
        }
    }

    private func downloadOne(_ p: PendingDownload) {
        downloads.enqueue(prepared: [p.toItem()])
        withAnimation(Theme.bouncy) { pending.removeAll { $0.id == p.id } }
    }
    private func downloadAll() {
        let ready = pending.filter { $0.probe != nil }
        downloads.enqueue(prepared: ready.map { $0.toItem() })
        withAnimation(Theme.smooth) { pending.removeAll { $0.probe != nil } }
    }

    // MARK: Active + recently finished (kept in place, faded)

    private var queueList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !downloads.active.isEmpty {
                Text(loc("dl.downloading")).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    .padding(.top, 6)
                ForEach(downloads.active) { DownloadRow(item: $0) }
            }
            let recent = Array(downloads.recentlyFinished.prefix(50))
            if !recent.isEmpty {
                Text(loc("dl.recent")).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textSecondary)
                    .padding(.top, 10)
                ForEach(recent) { DownloadRow(item: $0).opacity(0.62) }
            }
            if downloads.active.isEmpty && recent.isEmpty && pending.isEmpty { emptyState }
        }
        .animation(Theme.smooth, value: downloads.items.map(\.id))
    }

    private func sectionHeader(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Button(loc("common.clear"), action: action)
                .buttonStyle(.plain).font(.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 40)).foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text(loc("dl.subtitle")).font(.callout).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }
}

// MARK: - Platform icon with hover popover

struct PlatformIcon: View {
    let platform: Platform
    let active: Bool
    let matches: [PendingDownload]
    @State private var hovering = false

    private var label: String { platform == .generic ? (AppSettings.shared.language == .malay ? "Lain-lain" : "Others") : platform.label }

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: platform.symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(Circle().fill(active ? Theme.accent : Theme.surface))
                .overlay(Circle().strokeBorder(active ? Color.clear : Theme.border, lineWidth: 1))
                .foregroundStyle(active ? .white : Theme.textSecondary)
                .scaleEffect(active ? 1.08 : 1)
            Text(label).font(.system(size: 9, weight: active ? .bold : .regular))
                .foregroundStyle(active ? Theme.accent : Theme.textSecondary)
        }
        .onHover { hovering = $0 }
        .popover(isPresented: .constant(hovering && active && !matches.isEmpty), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(matches) { m in
                    HStack(spacing: 6) {
                        Image(systemName: m.platform.symbol).font(.caption2).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(m.probe?.title ?? loc("common.loading")).font(.caption.weight(.medium)).lineLimit(1)
                            Text(m.platform == .generic ? m.url : m.platform.label)
                                .font(.system(size: 9)).foregroundStyle(Theme.textSecondary).lineLimit(1)
                        }
                    }
                }
            }
            .padding(10).frame(width: 240)
        }
    }
}

// MARK: - Active download row

struct DownloadRow: View {
    let item: DownloadItem
    @ObservedObject private var downloads = DownloadManager.shared

    var body: some View {
        HStack(spacing: 14) {
            ThumbnailView(urlString: item.thumbnailURL, platform: item.platform)
                .frame(width: 128, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                if let ch = item.channel ?? item.uploader {
                    Text(ch).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Chip(text: item.type == .video ? loc("common.video") : loc("common.audio"),
                         symbol: item.type == .video ? "film" : "music.note", tint: Theme.accent)
                    if let q = item.qualityLabel ?? item.formatNote { Chip(text: q, symbol: "sparkles", tint: Theme.accent) }
                    if let e = item.ext { Chip(text: e.uppercased(), symbol: "doc", tint: Theme.textSecondary) }
                    if let s = item.fileSize ?? item.estimatedSize {
                        Chip(text: ByteCountFormatter.string(fromByteCount: s, countStyle: .file), symbol: "internaldrive", tint: Theme.textSecondary)
                    }
                }
                progressSection
            }
            Spacer()
            actionButtons
        }
        .padding(12)
        .glassCard(radius: Theme.rMd)
    }

    @ViewBuilder private var progressSection: some View {
        switch item.status {
        case .downloading:
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.border).frame(height: 6)
                        Capsule().fill(Theme.accent)
                            .frame(width: max(6, geo.size.width * min(item.progress.percent, 100) / 100), height: 6)
                    }
                }.frame(height: 6)
                HStack(spacing: 8) {
                    Text(String(format: "%.1f%%", item.progress.percent)).monospacedDigit()
                    if let s = item.progress.speed, !s.isEmpty { Text(s).monospacedDigit() }
                    if let eta = item.progress.eta, !eta.isEmpty { Text("ETA \(eta)").monospacedDigit() }
                }.font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            }
        case .processing:
            HStack(spacing: 6) { ProgressView().controlSize(.mini); Text(loc("common.finishing")).font(.caption).foregroundStyle(Theme.textSecondary) }
        case .pending:
            Text(loc("common.queued")).font(.caption).foregroundStyle(Theme.textSecondary)
        case .completed:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                Text(loc("common.saved")).font(.caption).foregroundStyle(Theme.textSecondary)
                MiniAction(symbol: "play.fill", help: loc("common.play")) { downloads.play(item) }
                MiniAction(symbol: "magnifyingglass", help: loc("common.reveal")) { downloads.revealInFinder(item) }
            }
        case .error:
            Text(item.errorMessage ?? loc("common.failed")).font(.caption).foregroundStyle(.red).lineLimit(1)
        default: EmptyView()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            if item.status == .error || item.status == .cancelled { RowButton(symbol: "arrow.clockwise") { downloads.retry(item.id) } }
            if [.pending, .downloading, .processing].contains(item.status) { RowButton(symbol: "xmark") { downloads.cancel(item.id) } }
        }
    }
}

struct Chip: View {
    let text: String; let symbol: String; let tint: Color
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 8, weight: .semibold))
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }
}

struct RowButton: View {
    let symbol: String; let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(hover ? Theme.surfaceHover : Theme.surface))
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                .foregroundStyle(Theme.textPrimary)
        }
        .buttonStyle(.plain).onHover { hover = $0 }.animation(Theme.snappy, value: hover)
    }
}

struct ThumbnailView: View {
    let urlString: String?
    let platform: Platform
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).fill(Theme.surfaceHover)
            if let s = urlString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fill) }
                    else { Image(systemName: platform.symbol).font(.title2).foregroundStyle(Theme.textSecondary) }
                }
            } else {
                Image(systemName: platform.symbol).font(.title2).foregroundStyle(Theme.textSecondary)
            }
        }
        .clipped()
    }
}
