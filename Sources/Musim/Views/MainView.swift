import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case library, archive, guide, settings
    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .archive: return "nav.archive"
        case .library: return "nav.library"
        case .guide: return "nav.guide"
        case .settings: return "nav.settings"
        }
    }
    var symbol: String {
        switch self {
        case .archive: return "archivebox"
        case .library: return "square.stack"
        case .guide: return "book.closed"
        case .settings: return "gearshape"
        }
    }
}

/// Modals presented over the whole app (dimmed backdrop, click-outside to close).
enum AppModal: String, Identifiable { case about; var id: String { rawValue } }

/// App shell: sidebar (collapses to a floating icon rail) · main content.
/// Activity lives in a dock system (bottom text → floating window). About and
/// How-to are click-outside-to-close modals.
struct MainView: View {
    @State private var section: SidebarSection = .library
    @State private var collapsed = false
    @State private var modal: AppModal?
    @StateObject private var activity = ActivityController.shared

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 0) {
                if !collapsed {
                    SidebarView(section: $section, collapsed: $collapsed, modal: $modal)
                        .frame(width: 220)
                        .transition(.move(edge: .leading))
                }
                ZStack {
                    switch section {
                    case .archive: DownloadPanel(onOpenActivity: { activity.state = .window })
                    case .library: LibraryView(onAddToArchive: { withAnimation { section = .archive } })
                    case .guide: PanduanView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // When the sidebar collapses to a floating rail, reserve a left
                // gutter so content is never hidden behind it.
                .padding(.leading, collapsed ? 82 : 0)
                .transition(.opacity)
                .id(section)
                .animation(Theme.smooth, value: section)
            }
            .background(Theme.bg)

            // Collapsed floating icon rail — vertically centred on the left edge.
            if collapsed {
                FloatingIconRail(section: $section, collapsed: $collapsed, modal: $modal)
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(.bottom, 36)
                    .transition(.scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
            }

            // Activity dock overlays
            ActivityDockOverlay()
        }
        .overlay {
            if let modal {
                ModalOverlay(onClose: { withAnimation(Theme.smooth) { self.modal = nil } }) {
                    switch modal {
                    case .about: AboutModal(onClose: { withAnimation(Theme.smooth) { self.modal = nil } })
                    }
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(Theme.smooth, value: collapsed)
        .animation(Theme.smooth, value: modal)
    }
}

/// A dimmed backdrop hosting a centred modal. Tapping the backdrop closes it;
/// taps on the content are swallowed so it stays open.
struct ModalOverlay<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
            content
                .contentShape(Rectangle())
                .onTapGesture { }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }
}

struct SidebarView: View {
    @Binding var section: SidebarSection
    @Binding var collapsed: Bool
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var downloads = DownloadManager.shared
    @Namespace private var pill

    @Binding var modal: AppModal?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo + user name (no app-name text) with a collapse control
            HStack(spacing: 10) {
                MusimLogo(size: 36)
                Text(settings.userName.isEmpty ? "Hai" : settings.userName)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Spacer()
                Button { withAnimation(Theme.smooth) { collapsed = true } } label: {
                    Image(systemName: "sidebar.left").font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }.buttonStyle(.plain).help("Collapse")
            }
            .padding(.horizontal, 16).padding(.top, 40).padding(.bottom, 22)

            VStack(spacing: 4) { ForEach(SidebarSection.allCases) { navButton($0) } }
                .padding(.horizontal, 10)

            Spacer()

            VStack(spacing: 4) {
                secondaryButton(icon: "info.circle", key: "nav.about") { modal = .about }
            }
            .padding(.horizontal, 10).padding(.bottom, 14)
        }
        .background(Theme.bgElevated)
        .patterned(tint: Theme.accent, opacity: 0.05)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.border).frame(width: 1) }
    }

    private func secondaryButton(icon: String, key: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon).font(.system(size: 15, weight: .medium)).frame(width: 22)
                Text(loc(key)).font(.system(size: 13.5, weight: .medium))
                Spacer()
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func navButton(_ s: SidebarSection) -> some View {
        Button { withAnimation(Theme.bouncy) { section = s } } label: {
            HStack(spacing: 11) {
                Image(systemName: section == s ? s.symbol + ".fill" : s.symbol)
                    .font(.system(size: 15, weight: .medium)).frame(width: 22)
                Text(loc(s.labelKey)).font(.system(size: 13.5, weight: .medium))
                Spacer()
                if s == .archive && !downloads.active.isEmpty {
                    Text("\(downloads.active.count)").font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(section == s ? Color.white.opacity(0.25) : Theme.accent))
                        .foregroundStyle(.white)
                }
            }
            .foregroundStyle(section == s ? Color.white : Theme.textPrimary)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background {
                if section == s {
                    RoundedRectangle(cornerRadius: Theme.rSm, style: .continuous).fill(Theme.accentGradient)
                        .matchedGeometryEffect(id: "pill", in: pill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsed floating icon rail

struct FloatingIconRail: View {
    @Binding var section: SidebarSection
    @Binding var collapsed: Bool
    @Binding var modal: AppModal?
    @ObservedObject private var downloads = DownloadManager.shared

    var body: some View {
        VStack(spacing: 8) {
            Button { withAnimation(Theme.smooth) { collapsed = false } } label: { MusimLogo(size: 34) }
                .buttonStyle(.plain).help("Expand")
            Divider().frame(width: 22)
            ForEach(SidebarSection.allCases) { s in
                iconButton(system: section == s ? s.symbol + ".fill" : s.symbol, active: section == s,
                           badge: s == .archive ? downloads.active.count : 0) {
                    withAnimation(Theme.bouncy) { section = s }
                }.help(loc(s.labelKey))
            }
            Divider().frame(width: 22)
            iconButton(system: "info.circle", active: false, badge: 0) { modal = .about }.help(loc("nav.about"))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
        .patternedRounded(20, opacity: 0.07)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 20, y: 8)
    }

    private func iconButton(system: String, active: Bool, badge: Int, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).font(.system(size: 16, weight: .medium))
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(active ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.clear)))
                .foregroundStyle(active ? Color.white : Theme.textSecondary)
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(4).background(Circle().fill(Theme.accent)).offset(x: 4, y: -4)
                    }
                }
        }.buttonStyle(.plain)
    }
}

// MARK: - About modal (localized, with a Support / DuitNow QR)

struct AboutModal: View {
    var onClose: () -> Void = {}
    @ObservedObject private var settings = AppSettings.shared
    @State private var showQR = false

    private var body_my: String {
        "MUSIM (Arkib + Simpan) v2.0 ialah arkib media peribadi natif Apple Silicon yang ringkas, bebas iklan, dan dikuasakan oleh seni bina sumber terbuka VidBee (Deno, yt-dlp, FFmpeg).\n\nDireka untuk menyimpan media dengan pantas daripada pelbagai sumber, ia turut dilengkapi dengan pustaka fail, pemain video terbina dalam, dan editor video. Aplikasi ini dihasilkan secara kolaboratif bersama Claude Fable 5 & Opus 4.8 oleh Fahim Zahar."
    }
    private var body_en: String {
        "MUSIM (Arkib + Simpan) v2.0 is a lightweight, ad-free, native Apple Silicon personal media archive powered by the open-source VidBee architecture (Deno, yt-dlp, FFmpeg).\n\nBuilt for fast local saves from many media sources, it includes a built-in player and a two-panel video editor. This app was created collaboratively with Claude Fable 5 & Opus 4.8 by Fahim Zahar."
    }
    /// Major tech powering Musim — engine, the AI collaborators, and the stack.
    static let techStack = [
        "Deno", "yt-dlp", "FFmpeg",
        "Claude Fable 5", "Claude Opus 4.8", "ChatGPT 5.5", "Gemini 3.5 Flash",
        "SwiftUI", "AVFoundation", "AppKit", "Swift"
    ]

    private var supportLabel: String { settings.language == .malay ? "Sokong Saya" : "Support Me" }
    private var doneLabel: String { settings.language == .malay ? "Tutup" : "Done" }
    private var backLabel: String { settings.language == .malay ? "Kembali" : "Back" }
    private var qrCaption: String {
        settings.language == .malay ? "Imbas dengan mana-mana aplikasi bank · DuitNow"
                                    : "Scan with any Malaysian banking app · DuitNow"
    }

    enum AboutTab: String, CaseIterable, Identifiable { case about, changelog, privacy, terms, licenses; var id: String { rawValue } }
    @State private var tab: AboutTab = .about

    private func tabLabel(_ t: AboutTab) -> String {
        let my = settings.language == .malay
        switch t {
        case .about:   return my ? "Perihal" : "About"
        case .changelog: return my ? "Perubahan" : "Changelog"
        case .privacy: return my ? "Privasi" : "Privacy"
        case .terms:   return my ? "Terma" : "Terms"
        case .licenses: return my ? "Lesen" : "Licenses"
        }
    }

    var body: some View {
        Group {
            if showQR { qrView } else { mainView }
        }
        .padding(28).frame(width: 520)
        .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(Theme.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 30, y: 14)
    }

    private var mainView: some View {
        VStack(spacing: 18) {
            Picker("", selection: $tab) {
                ForEach(AboutTab.allCases) { Text(tabLabel($0)).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().frame(width: 400)

            switch tab {
            case .about:   aboutView
            case .changelog: changelogView
            case .privacy: legalView("PRIVACY")
            case .terms:   legalView("TERMS")
            case .licenses: legalView("NOTICE")
            }
        }
    }

    private var aboutView: some View {
        VStack(spacing: 18) {
            MusimLogo(size: 74)
            VStack(spacing: 4) {
                Text("MUSIM").font(.system(size: 23, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text("Arkib + Simpan").font(.callout).foregroundStyle(Theme.textSecondary).tracking(2)
            }
            JustifiedText(text: settings.language == .malay ? body_my : body_en, width: 424)
                .frame(width: 424)
            FlowLayout(spacing: 7) {
                ForEach(Self.techStack, id: \.self) { t in
                    Text(t).font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(Theme.surfaceHover))
                        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 440)
            HStack(spacing: 10) {
                Button { withAnimation(Theme.bouncy) { showQR = true } } label: {
                    Label(supportLabel, systemImage: "heart.fill")
                }
                .buttonStyle(ExpressiveButtonStyle())
                Button(doneLabel) { onClose() }
                    .buttonStyle(GlassButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }
    }

    private var changelogView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(settings.language == .malay ? "Perubahan versi" : "Version history")
                    .font(.title3.weight(.bold)).foregroundStyle(Theme.textPrimary)
                changelogEntry(version: "2.0", date: "15 Jul 2026",
                               title: settings.language == .malay ? "Pemain & editor dibetulkan" : "Player & editor fixed",
                               body: settings.language == .malay
                                   ? "Tambah pemain video terbina dalam dan susun atur editor dua panel dengan garis masa di bawah video. Paparan editor kini lebih kemas; pilih nisbah crop, seret video terus dalam paparan, laraskan posisi, kemudian eksport dengan tetapan yang sama."
                                   : "Added the built-in video player and a two-panel editor with the timeline below the video. The editor viewer is now tidier: choose an aspect crop, drag the video directly in the viewer, adjust its position, and export with the same settings.")
                changelogEntry(version: "1.0", date: "10 Jul 2026",
                               title: settings.language == .malay ? "Keluaran pertama" : "First release",
                               body: settings.language == .malay
                                   ? "Simpan media video dan audio, pustaka fail, folder, nota lekat, serta tetapan penamaan fail."
                                   : "Saved video and audio media, file library, folders, sticky notes, and filename settings.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 440, height: 360)
    }

    private func changelogEntry(version: String, date: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("v\(version)").font(.headline.weight(.bold)).foregroundStyle(Theme.accent)
                Text(date).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            Text(body).font(.system(size: 13)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.rMd).fill(Theme.surface.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: Theme.rMd).strokeBorder(Theme.border, lineWidth: 1))
    }

    private func legalView(_ resource: String) -> some View {
        let text = (Bundle.main.url(forResource: resource, withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }) ?? "Not available."
        return VStack(spacing: 12) {
            ScrollView { MarkdownDoc(text: text).padding(.trailing, 6) }
                .frame(width: 464, height: 360)
                .background(RoundedRectangle(cornerRadius: Theme.rMd).fill(Theme.surface.opacity(0.4)))
                .overlay(RoundedRectangle(cornerRadius: Theme.rMd).strokeBorder(Theme.border, lineWidth: 1))
            Button(doneLabel) { onClose() }.buttonStyle(GlassButtonStyle())
        }
    }

    private var qrView: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text(supportLabel).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text(settings.language == .malay ? "Terima kasih atas sokongan anda 🤍" : "Thank you for your support 🤍")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            DuitNowQR().frame(width: 260, height: 260)
            Text(qrCaption).font(.caption).foregroundStyle(Theme.textSecondary)
            Button { withAnimation(Theme.bouncy) { showQR = false } } label: {
                Label(backLabel, systemImage: "chevron.left")
            }.buttonStyle(GlassButtonStyle())
        }
    }
}

/// Word-wrapped, fully justified paragraph text (SwiftUI `Text` can't justify).
struct JustifiedText: NSViewRepresentable {
    let text: String
    var size: CGFloat = 13.5
    var width: CGFloat = 408

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField(wrappingLabelWithString: text)
        tf.isEditable = false; tf.isSelectable = false; tf.isBezeled = false; tf.drawsBackground = false
        tf.lineBreakMode = .byWordWrapping
        return tf
    }
    func updateNSView(_ v: NSTextField, context: Context) {
        let p = NSMutableParagraphStyle()
        p.alignment = .justified
        p.lineSpacing = 3.5
        v.attributedStringValue = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: p
        ])
        v.preferredMaxLayoutWidth = width
    }
}

/// Lightweight markdown renderer for the legal documents: headings, bullets,
/// and inline bold/italic. Not a full parser — enough for these docs.
struct MarkdownDoc: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, raw in
                line(raw)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }

    @ViewBuilder private func line(_ raw: String) -> some View {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty {
            Spacer().frame(height: 3)
        } else if s.hasPrefix("# ") {
            Text(inline(String(s.dropFirst(2)))).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.textPrimary)
        } else if s.hasPrefix("## ") {
            Text(inline(String(s.dropFirst(3)))).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.textPrimary).padding(.top, 4)
        } else if s.hasPrefix("### ") {
            Text(inline(String(s.dropFirst(4)))).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Theme.textPrimary)
        } else if s.hasPrefix("- ") || s.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•").foregroundStyle(Theme.accent)
                Text(inline(String(s.dropFirst(2)))).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
        } else {
            Text(inline(s)).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineSpacing(2)
        }
    }

    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }
}

/// A simple flow layout that wraps chips onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

/// The DuitNow support QR, loaded from the bundle. Falls back to guidance if
/// the image hasn't been added yet.
struct DuitNowQR: View {
    @State private var hover = false
    @State private var zoomed = false

    private var qrImage: NSImage? {
        for name in ["duitnow", "duitnow-qr", "qr", "support-qr"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }
    var body: some View {
        if let img = qrImage {
            Image(nsImage: img).resizable().scaledToFit()
                .background(RoundedRectangle(cornerRadius: 14).fill(.white))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .scaleEffect(zoomed ? 1.65 : (hover ? 1.06 : 1), anchor: .center)
                .shadow(color: .black.opacity(zoomed ? 0.4 : 0), radius: 24, y: 10)
                .zIndex(zoomed ? 10 : 0)
                .onHover { hover = $0 }
                .onTapGesture { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { zoomed.toggle() } }
                .help(AppSettings.shared.language == .malay ? "Klik untuk zum" : "Click to zoom")
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surfaceHover)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode").font(.system(size: 40)).foregroundStyle(Theme.textSecondary)
                        Text("Add duitnow.png").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border, lineWidth: 1))
        }
    }
}
