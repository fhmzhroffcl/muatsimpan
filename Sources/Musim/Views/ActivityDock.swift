import SwiftUI

/// Controls the activity dock: a docked text label on the download page that
/// opens into a floating window. Click the label to open, click the window's
/// button (or anywhere outside) to minimise back to the label.
@MainActor
final class ActivityController: ObservableObject {
    static let shared = ActivityController()
    enum State { case docked, window }
    @Published var state: State = .docked
    private init() {}
}

// MARK: - Docked label (shown at the bottom of the download page)

struct ActivityDockLabel: View {
    var onOpen: () -> Void
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var activity = ActivityController.shared
    @State private var pulse = false

    private var activeCount: Int { downloads.active.count }
    private var overall: Double {
        let a = downloads.active
        guard !a.isEmpty else { return 0 }
        return a.map { min($0.progress.percent, 100) }.reduce(0, +) / Double(a.count)
    }

    var body: some View {
        if activity.state == .docked {
            Button(action: onOpen) {
                HStack(spacing: 9) {
                    if activeCount > 0 {
                        ZStack {
                            Circle().stroke(Theme.border, lineWidth: 2).frame(width: 16, height: 16)
                            Circle().trim(from: 0, to: overall/100)
                                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .rotationEffect(.degrees(-90)).frame(width: 16, height: 16)
                        }
                    } else {
                        Image(systemName: "square.stack.3d.up").font(.system(size: 12))
                    }
                    Text(loc("activity.title"))
                        .font(.system(size: 12, weight: .semibold))
                    if activeCount > 0 {
                        Text("· \(activeCount) · \(Int(overall))%")
                            .font(.system(size: 11, weight: .medium)).monospacedDigit()
                    }
                }
                .foregroundStyle(activeCount > 0 ? Theme.accent : Theme.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(activeCount > 0 ? Theme.accent.opacity(0.4) : Theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                .scaleEffect(pulse && activeCount > 0 ? 1.03 : 1)
            }
            .buttonStyle(.plain)
            .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true } }
            .animation(Theme.smooth, value: activeCount)
        }
    }
}

// MARK: - Global overlay hosting the window / bubble

struct ActivityDockOverlay: View {
    @ObservedObject private var activity = ActivityController.shared

    var body: some View {
        ZStack {
            if activity.state == .window {
                // Click anywhere outside the window to minimise it.
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(Theme.bouncy) { activity.state = .docked } }
                    .transition(.opacity)

                FloatingActivityWindow()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(20)
                    .transition(.scale(scale: 0.9, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .animation(Theme.bouncy, value: activity.state)
    }
}

// MARK: - Floating window (2 sizes, movable)

struct FloatingActivityWindow: View {
    @ObservedObject private var activity = ActivityController.shared
    @State private var tab: ActivityTab = .active
    @State private var playerItem: DownloadItem?
    @State private var clipItem: LibraryEntry?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill").font(.caption).foregroundStyle(Theme.accent)
                Text(loc("activity.title")).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { withAnimation(Theme.bouncy) { activity.state = .docked } } label: {
                    Image(systemName: "minus").font(.system(size: 11, weight: .semibold)).frame(width: 22, height: 22)
                }
                .buttonStyle(.plain).foregroundStyle(Theme.textSecondary).help("Minimise")
            }
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

            ActivityContent(tab: $tab, playerItem: $playerItem, clipItem: $clipItem)
        }
        .frame(width: 320, height: 420)
        .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(.ultraThinMaterial))
        .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(Theme.bgElevated.opacity(0.6)))
        .patternedRounded(Theme.rLg, opacity: 0.06)
        .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 26, y: 12)
        // Clicks inside the window must not fall through to the dismiss layer.
        .contentShape(Rectangle())
        .onTapGesture { }
        .sheet(item: $playerItem) { MiniPlayerView(item: $0) }
        .sheet(item: $clipItem) { ClipEditorView(entry: $0) }
    }
}

