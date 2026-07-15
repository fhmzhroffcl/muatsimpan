import SwiftUI
import AppKit
import Charts

// MARK: - Shared save-location picker

/// Opens the native folder chooser and repoints the archive (and the Library
/// root) at the picked directory. Shared by Settings, Arkib, and Pustaka so the
/// destination is changed the same way everywhere.
@MainActor
func chooseArchiveFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    if panel.runModal() == .OK, let url = panel.url {
        AppSettings.shared.downloadPath = url.path
        AppSettings.shared.ensureDownloadDirectory()
        LibraryStore.shared.open(folder: url)
    }
}

/// A small modal for changing where Musim saves media. Reached by tapping the
/// destination folder shown in Arkib or Pustaka, so the user never has to hunt
/// through Settings to move their archive.
struct SaveLocationSheet: View {
    var onClose: () -> Void = {}
    @ObservedObject private var settings = AppSettings.shared
    private var my: Bool { settings.language == .malay }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 26)).foregroundStyle(Theme.accent)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Theme.accentSoft))
                Text(my ? "Lokasi simpanan" : "Save location")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text(my ? "Semua media dan folder Pustaka disimpan di sini."
                        : "All media and your Library folders live here.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill").font(.caption).foregroundStyle(Theme.accent)
                Text(settings.downloadPath)
                    .font(.caption.monospaced()).foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Theme.rMd).fill(Theme.surface.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: Theme.rMd).strokeBorder(Theme.border, lineWidth: 1))

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "sparkles").font(.caption).foregroundStyle(Theme.accent)
                Text(my ? "Tip: anda juga boleh urus folder dan fail terus dalam Pustaka — cipta folder, seret media, dan namakan semula di sana."
                        : "Tip: you can also manage folders and files right inside Pustaka — make folders, drag media, and rename there.")
                    .font(.caption2).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: Theme.rMd).fill(Theme.accentSoft.opacity(0.4)))

            HStack(spacing: 10) {
                Button { chooseArchiveFolder() } label: {
                    Label(my ? "Tukar folder…" : "Change folder…", systemImage: "folder.badge.gearshape")
                }.buttonStyle(ExpressiveButtonStyle())
                Button(my ? "Tutup" : "Done") { onClose() }
                    .buttonStyle(GlassButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }
        .padding(28).frame(width: 420)
        .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(Theme.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 14)
    }
}

// MARK: - Archive statistics

private let statsVideoExts: Set<String> = ["mp4", "mkv", "webm", "mov", "m4v", "avi"]
private let statsAudioExts: Set<String> = ["mp3", "m4a", "aac", "wav", "flac", "opus", "ogg", "aiff", "alac"]

struct MediaBucket: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let bytes: Int64
}

struct ArchiveStats {
    var totalItems = 0
    var totalBytes: Int64 = 0
    var videoCount = 0
    var audioCount = 0
    var videoBytes: Int64 = 0
    var audioBytes: Int64 = 0
    var byPlatform: [MediaBucket] = []
    var byFormat: [MediaBucket] = []

    @MainActor
    static func build(from entries: [LibraryEntry]) -> ArchiveStats {
        var s = ArchiveStats()
        var platform: [String: (Int, Int64)] = [:]
        var format: [String: (Int, Int64)] = [:]
        let manager = DownloadManager.shared
        let my = AppSettings.shared.language == .malay

        for e in entries where e.isMedia && !e.isFolder {
            let ext = e.url.pathExtension.lowercased()
            let rec = manager.record(forPath: e.url.path)
            s.totalItems += 1
            s.totalBytes += e.size

            let isAudio = rec?.type == .audio || (rec?.type != .video && statsAudioExts.contains(ext))
            if isAudio {
                s.audioCount += 1; s.audioBytes += e.size
            } else {
                s.videoCount += 1; s.videoBytes += e.size
            }

            let platformLabel: String = {
                guard let p = rec?.platform, p != .generic else {
                    return rec?.platform == .generic ? "Web" : (my ? "Tempatan" : "Local")
                }
                return p.label
            }()
            let p = platform[platformLabel] ?? (0, 0)
            platform[platformLabel] = (p.0 + 1, p.1 + e.size)

            let fmt = ext.isEmpty ? (my ? "Lain" : "Other") : ext.uppercased()
            let f = format[fmt] ?? (0, 0)
            format[fmt] = (f.0 + 1, f.1 + e.size)
        }

        s.byPlatform = platform.map { MediaBucket(label: $0.key, count: $0.value.0, bytes: $0.value.1) }
            .sorted { $0.count > $1.count }
        s.byFormat = format.map { MediaBucket(label: $0.key, count: $0.value.0, bytes: $0.value.1) }
            .sorted { $0.count > $1.count }
        return s
    }
}

/// A friendly, interactive breakdown of the archive: how much is saved, the
/// video/audio split, and the top source platforms and formats. Opened from the
/// Pustaka summary card.
struct ArchiveStatsSheet: View {
    var onClose: () -> Void = {}
    @ObservedObject private var library = LibraryStore.shared
    @State private var stats = ArchiveStats()
    private var my: Bool { AppSettings.shared.language == .malay }

    private let palette: [Color] = [
        Color(hex: 0xE23744), Color(hex: 0xF4A300), Color(hex: 0x1AA179),
        Color(hex: 0x2D74DA), Color(hex: 0x8E5BD9), Color(hex: 0x0FB5C4),
        Color(hex: 0xE8688A)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(my ? "Simpanan anda" : "Your archive")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text(my ? "\(stats.totalItems) item · \(byteString(stats.totalBytes))"
                            : "\(stats.totalItems) items · \(byteString(stats.totalBytes))")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(Theme.textSecondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 14)

            if stats.totalItems == 0 {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        tiles
                        splitCard
                        if !stats.byPlatform.isEmpty { platformCard }
                        if !stats.byFormat.isEmpty { formatCard }
                    }
                    .padding(.horizontal, 22).padding(.bottom, 22)
                }
            }
        }
        .frame(width: 560, height: 640)
        .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(Theme.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 14)
        .onAppear { stats = ArchiveStats.build(from: library.allMedia()) }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.pie").font(.system(size: 44)).foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text(my ? "Belum ada media untuk dianalisis. Simpan sesuatu dahulu."
                    : "No media to chart yet. Save something first.")
                .font(.callout).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tiles: some View {
        HStack(spacing: 12) {
            statTile(icon: "film.fill", title: my ? "Video" : "Videos",
                     count: stats.videoCount, bytes: stats.videoBytes, color: palette[3])
            statTile(icon: "waveform", title: my ? "Audio" : "Audio",
                     count: stats.audioCount, bytes: stats.audioBytes, color: palette[2])
        }
    }

    private func statTile(icon: String, title: String, count: Int, bytes: Int64, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
                .frame(width: 42, height: 42).background(Circle().fill(color.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(byteString(bytes)).font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
        }
        .padding(14).frame(maxWidth: .infinity)
        .glassCard(radius: Theme.rMd)
    }

    private var splitCard: some View {
        let data = [
            MediaBucket(label: my ? "Video" : "Videos", count: stats.videoCount, bytes: stats.videoBytes),
            MediaBucket(label: my ? "Audio" : "Audio", count: stats.audioCount, bytes: stats.audioBytes)
        ].filter { $0.count > 0 }
        return card(title: my ? "Video lawan Audio" : "Video vs Audio", icon: "chart.pie.fill") {
            HStack(spacing: 20) {
                Chart(data) { bucket in
                    SectorMark(angle: .value("Count", bucket.count), innerRadius: .ratio(0.62), angularInset: 2)
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("Kind", bucket.label))
                }
                .chartForegroundStyleScale(range: [palette[3], palette[2]])
                .chartLegend(.hidden)
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { i, bucket in
                        HStack(spacing: 8) {
                            Circle().fill(i == 0 ? palette[3] : palette[2]).frame(width: 10, height: 10)
                            Text(bucket.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(percent(bucket.count, of: stats.totalItems))%")
                                .font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var platformCard: some View {
        card(title: my ? "Sumber teratas" : "Top sources", icon: "square.stack.3d.up.fill") {
            Chart(Array(stats.byPlatform.prefix(6))) { bucket in
                BarMark(x: .value("Count", bucket.count),
                        y: .value("Source", bucket.label))
                    .foregroundStyle(Theme.accentGradient)
                    .cornerRadius(5)
                    .annotation(position: .trailing) {
                        Text("\(bucket.count)").font(.caption2.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    }
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(min(6, stats.byPlatform.count)) * 34 + 10)
        }
    }

    private var formatCard: some View {
        card(title: my ? "Format teratas" : "Top formats", icon: "doc.badge.gearshape") {
            FlowLayout(spacing: 8) {
                ForEach(Array(stats.byFormat.prefix(8).enumerated()), id: \.element.id) { i, bucket in
                    HStack(spacing: 6) {
                        Circle().fill(palette[i % palette.count]).frame(width: 8, height: 8)
                        Text(bucket.label).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.textPrimary)
                        Text("\(bucket.count)").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.surface))
                    .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                }
            }
        }
    }

    private func card<C: View>(title: String, icon: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.textPrimary)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: Theme.rMd)
    }

    private func byteString(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
    }

    private func percent(_ value: Int, of total: Int) -> Int {
        total == 0 ? 0 : Int((Double(value) / Double(total) * 100).rounded())
    }
}
