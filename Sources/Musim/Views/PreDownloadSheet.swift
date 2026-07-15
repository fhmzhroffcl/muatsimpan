import SwiftUI

/// One pending link being configured inline on the download page.
@MainActor
final class PendingDownload: ObservableObject, Identifiable {
    let id = UUID().uuidString
    let url: String
    let platform: Platform
    @Published var probe: MediaProbe?
    @Published var error: String?
    @Published var type: MediaType
    @Published var selectedHeight: Int?    // nil = best available
    @Published var container: ContainerOption

    init(url: String, type: MediaType) {
        self.url = url
        self.platform = Platform.detect(from: url)
        self.type = type
        self.container = AppSettings.shared.container
    }

    var qualityLabel: String {
        if type == .audio { return "Audio MP3" }
        if let h = selectedHeight { return MediaProbe.heightLabel(h) }
        return AppSettings.shared.language == .malay ? "Terbaik" : "Best"
    }

    var formatSelector: String? {
        guard type == .video, let h = selectedHeight else { return nil }
        return "bestvideo[height<=\(h)]+bestaudio/best[height<=\(h)]/best"
    }

    func toItem() -> DownloadItem {
        var item = DownloadItem(url: url, title: probe?.title ?? url, type: type)
        item.thumbnailURL = probe?.thumbnail
        item.descriptionText = probe?.description
        item.uploader = probe?.uploader
        item.channel = probe?.channel
        item.duration = probe?.duration
        item.viewCount = probe?.viewCount
        item.platform = platform
        item.container = container
        item.formatSelector = formatSelector
        item.qualityLabel = qualityLabel
        item.estimatedSize = probe?.estimatedSize(height: selectedHeight ?? probe?.heights.first)
        if let h = selectedHeight ?? probe?.heights.first, type == .video {
            item.formatNote = MediaProbe.heightLabel(h)
        }
        item.ext = type == .audio ? "mp3" : (container == .auto ? "mp4" : container.rawValue)
        return item
    }
}

/// Inline card shown on the download page after pasting: loading shimmer →
/// preview + expressive quality/format controls the user verifies.
struct PendingCard: View {
    @ObservedObject var pending: PendingDownload
    var onRemove: () -> Void
    var onDownload: () -> Void
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                thumb
                VStack(alignment: .leading, spacing: 5) {
                    if let probe = pending.probe {
                        Text(probe.title).font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary).lineLimit(2)
                        HStack(spacing: 6) {
                            platformBadge
                            if let ch = probe.channel { Text(ch).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1) }
                            if let v = probe.viewCount {
                                Text("· \(viewString(v)) \(AppSettings.shared.language == .malay ? "tontonan" : "views")")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        if let desc = probe.description, !desc.isEmpty {
                            Text(desc).font(.caption).foregroundStyle(Theme.textSecondary)
                                .lineLimit(expanded ? nil : 2)
                            Button(loc(expanded ? "dl.readless" : "dl.readmore")) {
                                withAnimation(Theme.smooth) { expanded.toggle() }
                            }
                            .buttonStyle(.plain).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.accent)
                        }
                    } else if let err = pending.error {
                        Text(pending.url).font(.caption).lineLimit(1).foregroundStyle(.secondary)
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange).lineLimit(2)
                    } else {
                        loadingLines
                    }
                    Spacer(minLength: 0)
                }
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                .buttonStyle(.plain)
            }

            if let probe = pending.probe {
                controls(probe)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(16)
        .glassCard(radius: Theme.rMd, glow: pending.probe != nil)
        .animation(Theme.smooth, value: pending.probe != nil)
        .animation(Theme.bouncy, value: pending.type)
    }

    // MARK: pieces

    @ViewBuilder private var thumb: some View {
        ThumbnailView(urlString: pending.probe?.thumbnail, platform: pending.platform)
            .frame(width: 156, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if let d = pending.probe?.duration {
                    Text(timeString(d))
                        .font(.system(size: 9, weight: .bold).monospacedDigit())
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.7)))
                        .foregroundStyle(.white).padding(5)
                }
            }
            .overlay {
                if pending.probe == nil && pending.error == nil {
                    RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous)
                        .fill(.ultraThinMaterial).shimmering()
                }
            }
    }

    private var platformBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: pending.platform.symbol).font(.system(size: 8, weight: .bold))
            Text(pending.platform.label).font(.system(size: 10, weight: .bold))
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(Theme.accentGradient))
        .foregroundStyle(.white)
    }

    private var loadingLines: some View {
        VStack(alignment: .leading, spacing: 7) {
            RoundedRectangle(cornerRadius: 5).fill(.primary.opacity(0.08)).frame(width: 200, height: 13).shimmering()
            RoundedRectangle(cornerRadius: 5).fill(.primary.opacity(0.08)).frame(width: 130, height: 10).shimmering()
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(loc("dl.reading")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder private func controls(_ probe: MediaProbe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // type toggle
            HStack(spacing: 8) {
                ForEach(MediaType.allCases) { t in
                    let on = pending.type == t
                    Button {
                        withAnimation(Theme.bouncy) { pending.type = t }
                    } label: {
                        Label(t.label, systemImage: t == .video ? "film" : "music.note")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(.ultraThinMaterial)))
                            .foregroundStyle(on ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if let size = probe.estimatedSize(height: pending.selectedHeight ?? probe.heights.first), pending.type == .video {
                    chip("≈ " + ByteCountFormatter.string(fromByteCount: size, countStyle: .file), "internaldrive", .green)
                }
            }

            // quality chips (video)
            if pending.type == .video && !probe.heights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        qualityChip(label: AppSettings.shared.language == .malay ? "Terbaik" : "Best", height: nil)
                        ForEach(probe.heights, id: \.self) { h in
                            qualityChip(label: MediaProbe.heightLabel(h), height: h, is8k: h >= 4320)
                        }
                    }
                }
                // container
                HStack(spacing: 7) {
                    Text(loc("common.format")).font(.caption).foregroundStyle(.secondary)
                    ForEach(ContainerOption.allCases) { c in
                        let on = pending.container == c
                        Button { withAnimation(Theme.snappy) { pending.container = c } } label: {
                            Text(c == .auto ? "Auto" : c.label)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(on ? AnyShapeStyle(Theme.accent.opacity(0.9)) : AnyShapeStyle(.ultraThinMaterial)))
                                .foregroundStyle(on ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: onDownload) {
                Label(AppSettings.shared.language == .malay ? "Simpan ini" : "Save this", systemImage: "archivebox.fill")
            }
            .buttonStyle(ExpressiveButtonStyle())
        }
    }

    private func qualityChip(label: String, height: Int?, is8k: Bool = false) -> some View {
        let on = pending.selectedHeight == height
        return Button {
            withAnimation(Theme.bouncy) { pending.selectedHeight = height }
        } label: {
            HStack(spacing: 4) {
                if is8k { Image(systemName: "sparkles").font(.system(size: 8, weight: .bold)) }
                Text(label).font(.system(size: 12, weight: .bold))
            }
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(
                Capsule().fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(Capsule().strokeBorder(.white.opacity(on ? 0 : 0.12), lineWidth: 1))
            .foregroundStyle(on ? .white : .primary)
            .shadow(color: on ? Theme.accent.opacity(0.4) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .scaleEffect(on ? 1.05 : 1)
    }

    private func chip(_ text: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 8, weight: .semibold))
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(tint)
    }

    private func timeString(_ t: Double) -> String {
        let s = Int(t)
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
    private func viewString(_ v: Int) -> String {
        switch v {
        case 1_000_000...: return String(format: "%.1fM", Double(v) / 1_000_000)
        case 1_000...: return String(format: "%.1fK", Double(v) / 1_000)
        default: return "\(v)"
        }
    }
}
