import SwiftUI
import AVFoundation

enum ActivityTab: String, CaseIterable {
    case active, history
    var key: String { self == .active ? "activity.active" : "activity.history" }
}

/// Shared tabbed list used by both the panel and the floating widget.
struct ActivityContent: View {
    @Binding var tab: ActivityTab
    @Binding var playerItem: DownloadItem?
    @Binding var clipItem: LibraryEntry?
    @ObservedObject private var downloads = DownloadManager.shared
    @Namespace private var tabNS
    @State private var confirmClear = false

    private var shown: [DownloadItem] { tab == .active ? downloads.active : downloads.history }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(ActivityTab.allCases, id: \.self) { t in
                    Button { withAnimation(Theme.bouncy) { tab = t } } label: {
                        HStack(spacing: 5) {
                            Text(loc(t.key)).font(.caption.weight(.semibold))
                            let count = t == .active ? downloads.active.count : downloads.history.count
                            if count > 0 {
                                Text("\(count)").font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(tab == t ? Color.white.opacity(0.25) : Theme.border))
                                    .foregroundStyle(tab == t ? .white : Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(tab == t ? Color.white : Theme.textSecondary)
                        .background {
                            if tab == t {
                                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Theme.accent)
                                    .matchedGeometryEffect(id: "tab", in: tabNS)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surfaceHover))
            .padding(.horizontal, 12).padding(.bottom, 10)

            if tab == .history && !downloads.history.isEmpty {
                HStack {
                    Spacer()
                    Button(role: .destructive) { confirmClear = true } label: {
                        Label(loc("act.clearHistory"), systemImage: "trash").font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain).foregroundStyle(.red)
                }
                .padding(.horizontal, 14).padding(.bottom, 8)
                .confirmationDialog(loc("act.clearHistory"), isPresented: $confirmClear, titleVisibility: .visible) {
                    Button(loc("act.clearHistory"), role: .destructive) { downloads.clearHistory() }
                    Button(loc("common.cancel"), role: .cancel) {}
                } message: {
                    Text(loc("act.clearNotice"))
                }
            }

            if shown.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: tab == .active ? "arrow.down.circle" : "clock.arrow.circlepath")
                        .font(.system(size: 28)).foregroundStyle(Theme.textSecondary.opacity(0.5))
                    Text(tab == .active ? loc("activity.empty") : loc("activity.history"))
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(shown) { ActivityRow(item: $0, playerItem: $playerItem, clipItem: $clipItem) }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 16)
                    .animation(Theme.smooth, value: shown.map(\.id))
                }
            }
        }
    }
}

struct ActivityRow: View {
    let item: DownloadItem
    @Binding var playerItem: DownloadItem?
    @Binding var clipItem: LibraryEntry?
    @ObservedObject private var downloads = DownloadManager.shared
    @State private var hover = false

    private var fileExists: Bool {
        guard let p = item.savedFilePath else { return false }
        return FileManager.default.fileExists(atPath: p)
    }

    private var isVideoFile: Bool {
        guard let p = item.savedFilePath else { return false }
        return ["mp4","mkv","webm","mov","m4v"].contains(URL(fileURLWithPath: p).pathExtension.lowercased())
    }

    /// Build a Library entry from the saved file so it can be edited in place.
    private func makeEntry() -> LibraryEntry? {
        guard let p = item.savedFilePath, FileManager.default.fileExists(atPath: p) else { return nil }
        let url = URL(fileURLWithPath: p)
        let attrs = try? FileManager.default.attributesOfItem(atPath: p)
        return LibraryEntry(id: p, url: url, name: url.lastPathComponent, isFolder: false,
                            size: (attrs?[.size] as? Int64) ?? 0,
                            modified: (attrs?[.modificationDate] as? Date) ?? Date(), isMedia: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusIcon
                Text(item.title).font(.caption.weight(.medium)).lineLimit(2)
                Spacer(minLength: 0)
            }

            if item.status == .downloading {
                ProgressView(value: item.progress.percent, total: 100)
                    .progressViewStyle(.linear)
                    .controlSize(.small)
                HStack {
                    Text(String(format: "%.0f%%", item.progress.percent))
                    Spacer()
                    if let s = item.progress.speed { Text(s) }
                }
                .font(.system(size: 9)).monospacedDigit().foregroundStyle(.secondary)
            }

            if item.status == .completed && (hover || true) {
                HStack(spacing: 6) {
                    if let date = item.completedAt {
                        Text(date, style: .relative).font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if fileExists {
                        MiniAction(symbol: "play.fill", help: loc("act.playInApp")) { playerItem = item }
                        if isVideoFile {
                            MiniAction(symbol: "scissors", help: loc("act.edit")) { clipItem = makeEntry() }
                        }
                    }
                    MiniAction(symbol: "magnifyingglass", help: loc("act.reveal")) { downloads.revealInFinder(item) }
                    MiniAction(symbol: "trash", help: loc("act.remove")) { downloads.remove(item.id) }
                }
            }
            if item.status == .error {
                HStack {
                    Spacer()
                    MiniAction(symbol: "arrow.clockwise", help: loc("act.retry")) { downloads.retry(item.id) }
                    MiniAction(symbol: "trash", help: loc("act.remove")) { downloads.remove(item.id) }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hover ? Color.primary.opacity(0.06) : Color.primary.opacity(0.025))
        )
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
        case .error:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.caption)
        case .cancelled:
            Image(systemName: "slash.circle").foregroundStyle(.secondary).font(.caption)
        case .downloading, .processing:
            ProgressView().controlSize(.mini)
        default:
            Image(systemName: "clock").foregroundStyle(.secondary).font(.caption)
        }
    }
}

struct MiniAction: View {
    let symbol: String
    let help: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 22, height: 22)
                .background(Circle().fill(.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Mini player

struct MiniPlayerView: View {
    let item: DownloadItem
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            if let player {
                PlayerView(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
            }
            HStack {
                Text(item.title).font(.callout.weight(.medium)).lineLimit(1)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 640)
        .onAppear {
            if let p = item.savedFilePath {
                player = AVPlayer(url: URL(fileURLWithPath: p))
                player?.play()
            }
        }
        .onDisappear { player?.pause() }
    }
}
