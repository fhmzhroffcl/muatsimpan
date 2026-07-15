import SwiftUI
import AppKit

/// Full settings — mirrors VidBee's Settings page.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var ytdlp = YtDlpManager.shared
    private var my: Bool { settings.language == .malay }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(my ? "Tetapan" : "Settings").font(.system(size: 22, weight: .bold))
                    Text(my ? "Tetapkan bagaimana Musim menyimpan dan menyusun media anda." : "Tune how Musim saves and organizes your media.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                group(my ? "Umum" : "General", icon: "person.fill") {
                    row(my ? "Nama Anda" : "Your Name") {
                        TextField(my ? "Nama" : "Name", text: $settings.userName).textFieldStyle(.roundedBorder).frame(width: 180)
                    }
                    row(my ? "Bahasa" : "Language") {
                        Picker("", selection: $settings.language) {
                            ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().frame(width: 160)
                        .onChange(of: settings.language) { _, _ in GreetingEngine.shared.refresh() }
                    }
                }

                group(my ? "Pemberitahuan" : "Notifications", icon: "bell.fill") {
                    row(my ? "Beritahu bila simpanan selesai" : "Notify when a save finishes") {
                        Toggle("", isOn: $settings.notifyOnComplete).labelsHidden().toggleStyle(.switch)
                    }
                }

                group(my ? "Tema" : "Theme", icon: "paintpalette.fill") {
                    row(my ? "Rupa" : "Appearance") {
                        Picker("", selection: $settings.appearance) {
                            ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
                        }.pickerStyle(.segmented).labelsHidden().frame(width: 230)
                    }
                    row(my ? "Warna Aksen" : "Accent Color", subtitle: my ? "Palet berinspirasikan Malaysia" : "Malaysian-inspired palette") {
                        HStack(spacing: 8) {
                            ForEach(AccentPalette.options) { opt in
                                Circle().fill(Color(hex: opt.hex))
                                    .frame(width: 22, height: 22)
                                    .overlay(Circle().strokeBorder(Theme.textPrimary.opacity(settings.accent == opt.id ? 0.8 : 0), lineWidth: 2))
                                    .overlay(Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white).opacity(settings.accent == opt.id ? 1 : 0))
                                    .onTapGesture { withAnimation(Theme.bouncy) { settings.accent = opt.id } }
                                    .help(opt.name)
                            }
                        }
                    }
                    row(my ? "Corak" : "Pattern", subtitle: my ? "Motif halus pada panel" : "Subtle motif on panels") {
                        Picker("", selection: $settings.pattern) {
                            ForEach(PatternStyle.allCases) { Text($0.label).tag($0.rawValue) }
                        }.labelsHidden().frame(width: 150)
                    }
                }

                group(my ? "Arkib" : "Archive", icon: "archivebox.fill") {
                    row(my ? "Simpan media di" : "Save media to",
                        info: my ? "Ini juga folder Pustaka. Musim akan cipta folder YouTube, TikTok, Facebook dan Instagram di sini."
                                 : "This is also your Library folder. Musim creates YouTube, TikTok, Facebook and Instagram folders here.") {
                        HStack(spacing: 8) {
                            Text(settings.downloadPath)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                .frame(maxWidth: 220, alignment: .trailing)
                            Button(my ? "Pilih…" : "Choose…") { pickFolder() }
                        }
                    }
                    row(my ? "Simpan sejarah arkib" : "Log archive history",
                        subtitle: my ? "Fail teks laporan sejarah arkib disimpan di dalam folder Laporan"
                                     : "Archive-history report text files are saved in the Report folder",
                        info: my ? "Jangan simpan fail hanya menyimpan sejarah dalam app. Kosongkan sejarah untuk memadamnya."
                                 : "Don’t save a file keeps the log in-app only — clearing history erases it.") {
                        Picker("", selection: $settings.historyLog) {
                            ForEach(HistoryLogFrequency.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().frame(width: 150)
                    }
                    row(my ? "Simpanan serentak" : "Concurrent saves") {
                        Stepper("\(settings.maxConcurrentDownloads)", value: $settings.maxConcurrentDownloads, in: 1...10)
                            .frame(width: 100)
                    }
                    row(my ? "Jenis lalai" : "Default type") {
                        Picker("", selection: $settings.oneClickType) {
                            ForEach(MediaType.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().frame(width: 120)
                    }
                    row(my ? "Kualiti lalai" : "Default quality") {
                        Picker("", selection: $settings.oneClickQuality) {
                            ForEach(QualityPreset.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().frame(width: 160)
                    }
                    row(my ? "Bekas output" : "Output container") {
                        Picker("", selection: $settings.container) {
                            ForEach(ContainerOption.allCases) { Text($0.label).tag($0) }
                        }.labelsHidden().frame(width: 160)
                    }
                    row(my ? "Susun ikut platform" : "Organize by platform",
                        info: my ? "Setiap sumber disimpan dalam folder platform seperti YouTube, TikTok, Facebook atau Instagram. Sumber baharu akan dapat folder sendiri."
                                 : "Each source is saved into a platform folder. New sources get their own folder.") {
                        Toggle("", isOn: $settings.organizeByPlatform).labelsHidden().toggleStyle(.switch)
                    }
                    row(my ? "Subfolder pencipta" : "Creator subfolders",
                        info: my ? "Setiap pencipta mendapat subfolder sendiri di dalam folder platform."
                                 : "Each creator gets their own subfolder inside the platform folder.") {
                        Toggle("", isOn: $settings.channelSubfolders).labelsHidden().toggleStyle(.switch)
                    }
                }

                group(my ? "Penamaan" : "Naming", icon: "textformat") {
                    row(my ? "Namakan fail dari tajuk video" : "Auto-name files from video title") {
                        Toggle("", isOn: $settings.autoNaming).labelsHidden().toggleStyle(.switch)
                    }
                    row(my ? "Penamaan lanjutan" : "Advanced naming",
                        subtitle: my ? "Awalan, tarikh, nombor & akhiran" : "Prefix, date, counter & suffix") {
                        Toggle("", isOn: $settings.advancedNaming).labelsHidden().toggleStyle(.switch)
                            .disabled(!settings.autoNaming)
                    }
                    if settings.autoNaming && settings.advancedNaming {
                        row(my ? "Awalan / Akhiran" : "Prefix / Suffix") {
                            HStack(spacing: 6) {
                                TextField(my ? "Awalan" : "Prefix", text: $settings.namePrefix).textFieldStyle(.roundedBorder).frame(width: 96)
                                TextField(my ? "Akhiran" : "Suffix", text: $settings.nameSuffix).textFieldStyle(.roundedBorder).frame(width: 96)
                            }
                        }
                        row(my ? "Pemisah" : "Separator") {
                            Picker("", selection: $settings.nameSeparator) {
                                Text(my ? "- (Sengkang)" : "- (Hyphen)").tag(" - ")
                                Text(my ? "_ (Garis bawah)" : "_ (Underscore)").tag("_")
                                Text(my ? "Ruang" : "Space").tag(" ")
                            }.labelsHidden().frame(width: 160)
                        }
                        row(my ? "Tarikh" : "Date") {
                            Picker("", selection: $settings.nameDate) {
                                Text(my ? "Tiada" : "None").tag("none")
                                Text("YYYYMMDD").tag("%Y%m%d")
                                Text("YYYY-MM-DD").tag("%Y-%m-%d")
                            }.labelsHidden().frame(width: 160)
                        }
                        row(my ? "Nombor turutan" : "Start number",
                            info: my ? "Tambah nombor berurutan (001, 002, …) pada nama fail." : "Adds a running number (001, 002, …) to filenames.") {
                            Toggle("", isOn: $settings.nameCounter).labelsHidden().toggleStyle(.switch)
                        }
                        HStack {
                            Text(my ? "Contoh:" : "Example:").font(.caption2).foregroundStyle(.tertiary)
                            Text(settings.namingExample()).font(.caption2.monospaced()).foregroundStyle(Theme.accent).lineLimit(1).truncationMode(.middle)
                            Spacer()
                        }.padding(.horizontal, 14).padding(.bottom, 6)
                    } else {
                        row(my ? "Templat nama fail" : "Filename template", subtitle: my ? "Templat output yt-dlp" : "yt-dlp output template") {
                            TextField("%(title)s.%(ext)s", text: $settings.filenameTemplate)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption.monospaced())
                                .frame(width: 220)
                                .disabled(!settings.autoNaming)
                        }
                    }
                }

                group(my ? "Rangkaian & Kuki" : "Network & Cookies", icon: "key.fill") {
                    row(my ? "Kuki pelayar" : "Browser cookies", subtitle: browserSubtitle,
                        info: my ? "Kuki membantu Musim menyimpan video peribadi atau yang perlu log masuk. Musim membacanya terus daripada pelayar di Mac ini sahaja."
                                 : "Cookies let Musim save private/login-required videos. Musim reads them straight from your browser on this Mac only.") {
                        Picker("", selection: $settings.browserForCookies) {
                            ForEach(AppSettings.browsers, id: \.self) { b in
                                Text(browserName(b)).tag(b)
                            }
                        }.labelsHidden().frame(width: 150)
                    }
                    if settings.usesCookies {
                        cookiesNote
                    }
                    row(my ? "Proksi" : "Proxy", subtitle: "cth. socks5://127.0.0.1:1080") {
                        TextField(my ? "Pilihan" : "Optional", text: $settings.proxy)
                            .textFieldStyle(.roundedBorder).frame(width: 220)
                    }
                }

                group(my ? "Sematan" : "Embedding", icon: "square.and.arrow.down.on.square.fill") {
                    row(my ? "Semat sari kata" : "Embed subtitles",
                        info: my ? "Hanya untuk laman yang menyediakan sari kata seperti YouTube atau Vimeo. Diabaikan jika tiada."
                                 : "Only for sites that provide subtitles (e.g. YouTube, Vimeo). Ignored when none exist.") {
                        Toggle("", isOn: $settings.embedSubs).labelsHidden().toggleStyle(.switch) }
                    row(my ? "Semat lakaran kecil" : "Embed thumbnail",
                        info: my ? "Menyematkan lakaran kecil sebagai kulit video atau audio. Kebanyakan laman menyokongnya."
                                 : "Embeds the thumbnail as cover art (MP4/MKV/MP3). Most sites support this.") {
                        Toggle("", isOn: $settings.embedThumbnail).labelsHidden().toggleStyle(.switch) }
                    row(my ? "Semat metadata" : "Embed metadata",
                        info: my ? "Menyimpan tajuk, pencipta dan tarikh ke dalam fail."
                                 : "Writes title, creator & date into the file. Widely supported.") {
                        Toggle("", isOn: $settings.embedMetadata).labelsHidden().toggleStyle(.switch) }
                    row(my ? "Semat bab" : "Embed chapters",
                        info: my ? "Hanya untuk video yang mempunyai bab, kebanyakannya YouTube. Diabaikan jika tiada."
                                 : "Only for videos that have chapters (mostly YouTube). Ignored when none exist.") {
                        Toggle("", isOn: $settings.embedChapters).labelsHidden().toggleStyle(.switch) }
                }

                group(my ? "Enjin" : "Engine", icon: "gearshape.2.fill") {
                    row(my ? "Kemas kini automatik" : "Auto-update engine",
                        subtitle: my ? "Semak dan kemas kini yt-dlp secara automatik semasa app dibuka"
                                     : "Check & update yt-dlp automatically on launch, with an in-app notice") {
                        Toggle("", isOn: $settings.autoUpdateEngine).labelsHidden().toggleStyle(.switch)
                    }
                    row("yt-dlp", subtitle: ytdlp.binaryPath ?? (my ? "Belum dipasang" : "Not installed")) {
                        if ytdlp.isInstalling {
                            HStack(spacing: 6) { ProgressView().controlSize(.small)
                                Text(my ? "Menyemak…" : "Checking…").font(.caption).foregroundStyle(.secondary) }
                        } else {
                            Button(ytdlp.binaryPath == nil ? (my ? "Pasang" : "Install")
                                                           : (my ? "Semak kemas kini" : "Check for updates")) {
                                Task { await ytdlp.install() }
                            }
                        }
                    }
                    row("ffmpeg", subtitle: ytdlp.ffmpegPath ?? (my ? "Tidak ditemui. Cantuman video mungkin terhad." : "Not found (merging may be limited) — brew install ffmpeg")) {
                        Image(systemName: ytdlp.ffmpegPath != nil ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(ytdlp.ffmpegPath != nil ? .green : .orange)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var browserSubtitle: String {
        if settings.browserForCookies == "none" {
            return my ? "Dimatikan. Kebanyakan video awam boleh disimpan tanpa ini." : "Off — most public videos work without this"
        }
        let b = settings.resolvedCookieBrowser.capitalized
        return settings.browserForCookies == "auto"
            ? (my ? "Guna pelayar lalai anda (\(b))" : "Using your default browser (\(b))")
            : (my ? "Baca kuki daripada \(b)" : "Reading cookies from \(b)")
    }

    private func browserName(_ browser: String) -> String {
        if browser == "none" { return my ? "Dimatikan" : "Off" }
        if browser == "auto" { return my ? "Pelayar lalai" : "Default browser" }
        return browser.capitalized
    }

    @ViewBuilder private var cookiesNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Theme.accent)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(my ? "Cara kuki berfungsi di macOS" : "How cookies work on macOS")
                    .font(.caption.weight(.semibold))
                Text(my ? "Kuki membantu Musim menyimpan video peribadi atau perlu log masuk seperti Facebook dan Instagram. macOS mungkin minta kata laluan Keychain supaya Musim boleh baca kuki. Tutup pelayar yang dipilih dahulu jika simpanan tersekat."
                        : "Cookies let Musim save private or login-required videos (e.g. Facebook, Instagram). macOS may ask for your **Keychain password** so Musim can read them — this is normal and safe. Quit the chosen browser first if a save stalls, since it can lock the cookie store.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadPath = url.path
            settings.ensureDownloadDirectory()
            LibraryStore.shared.open(folder: url)
        }
    }

    private func group<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(Color.accentColor).font(.callout)
                Text(title).font(.headline)
            }
            .padding(.bottom, 10)
            VStack(spacing: 0) { content() }
                .padding(.vertical, 4)
                .glassCard(radius: Theme.rMd)
        }
    }

    private func row<Content: View>(_ title: String, subtitle: String? = nil, info: String? = nil, @ViewBuilder control: () -> Content) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(title).font(.callout)
                    if let info {
                        Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.tertiary).help(info)
                    }
                }
                if let subtitle {
                    Text(subtitle).font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

/// Brand colours for the featured platforms.
enum BrandColors {
    static func color(_ name: String) -> Color {
        switch name.lowercased() {
        case let n where n.contains("youtube"): return Color(hex: 0xFF0000)
        case let n where n.contains("tiktok"): return Color(hex: 0x25F4EE)
        case let n where n.contains("instagram"): return Color(hex: 0xE1306C)
        case let n where n.contains("twitter") || n.contains("x /"): return Color(hex: 0x1DA1F2)
        case let n where n.contains("facebook"): return Color(hex: 0x1877F2)
        case let n where n.contains("vimeo"): return Color(hex: 0x1AB7EA)
        case let n where n.contains("twitch"): return Color(hex: 0x9146FF)
        case let n where n.contains("soundcloud"): return Color(hex: 0xFF5500)
        case let n where n.contains("bilibili"): return Color(hex: 0x00A1D6)
        case let n where n.contains("reddit"): return Color(hex: 0xFF4500)
        case let n where n.contains("dailymotion"): return Color(hex: 0x0066DC)
        case let n where n.contains("bandcamp"): return Color(hex: 0x629AA9)
        case let n where n.contains("rumble"): return Color(hex: 0x85C742)
        case let n where n.contains("pinterest"): return Color(hex: 0xE60023)
        case let n where n.contains("linkedin"): return Color(hex: 0x0A66C2)
        case let n where n.contains("tumblr"): return Color(hex: 0x36465D)
        case let n where n.contains("vk"): return Color(hex: 0x0077FF)
        case let n where n.contains("streamable"): return Color(hex: 0x0F90FA)
        default: return Theme.accent
        }
    }
}

/// Supported sites: an auto-advancing carousel of the top 10 (official logos,
/// click to open) + a searchable, magnifying chip list of the 1000+ rest.
struct SupportedSitesView: View {
    @State private var search = ""
    @State private var allSites: [String] = []
    @State private var loadingAll = false

    private var featured: [SupportedSite] { Array(SupportedSite.featured.prefix(10)) }
    private var filteredFeatured: [SupportedSite] {
        search.isEmpty ? featured
            : SupportedSite.featured.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.domain.localizedCaseInsensitiveContains(search) }
    }
    private var filteredAll: [String] {
        search.isEmpty ? allSites : allSites.filter { $0.localizedCaseInsensitiveContains(search) }
    }
    private var my: Bool { AppSettings.shared.language == .malay }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("nav.sites")).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text(allSites.isEmpty ? (my ? "Platform utama siap. Senarai penuh dimuat bila diperlukan." : "Featured platforms are ready. Full list loads only when needed.")
                                          : (my ? "\(allSites.count) sumber tersedia" : "\(allSites.count) sources available"))
                        .font(.callout).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                    TextField(my ? "Cari laman" : "Search sites", text: $search).textFieldStyle(.plain).foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Capsule().fill(Theme.surface)).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                .frame(maxWidth: 240)
            }
            .padding(.horizontal, 24).padding(.top, 40).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if search.isEmpty {
                        FeaturedCarousel(sites: featured)
                    } else if !filteredFeatured.isEmpty {
                        Text(my ? "PADANAN" : "MATCHES").font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.textSecondary).tracking(1)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 14)], spacing: 14) {
                            ForEach(filteredFeatured) { BigSiteCard(site: $0, height: 150) }
                        }
                    }
                    if allSites.isEmpty && search.isEmpty {
                        Button {
                            loadAllSites()
                        } label: {
                            Label(loadingAll ? (my ? "Memuat senarai…" : "Loading list…") : (my ? "Muat Senarai Penuh 1000+ Laman" : "Load Full 1000+ Site List"),
                                  systemImage: "list.bullet.rectangle")
                        }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(loadingAll)
                    }
                    if loadingAll {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(my ? "Membaca senarai penuh daripada enjin yt-dlp…" : "Reading the full list from the yt-dlp engine…")
                                .font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                    if !filteredAll.isEmpty {
                        Text(my ? "SEMUA LAMAN" : "ALL SITES").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textSecondary).tracking(1)
                            .padding(.top, 8)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120, maximum: 200), spacing: 8)], spacing: 8) {
                            ForEach(filteredAll, id: \.self) { SiteChip(name: $0) }
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(Theme.bg)
        .onChange(of: search) { _, value in
            if !value.trimmingCharacters(in: .whitespaces).isEmpty, allSites.isEmpty {
                loadAllSites()
            }
        }
    }

    private func loadAllSites() {
        guard !loadingAll, allSites.isEmpty else { return }
        loadingAll = true
        Task {
            let sites = await MediaProber.allExtractors()
            await MainActor.run {
                allSites = sites
                loadingAll = false
            }
        }
    }
}

/// Auto-advancing showcase of the top platforms; pauses on hover so the user
/// can take over (scroll freely). Clicking a card opens the site.
struct FeaturedCarousel: View {
    let sites: [SupportedSite]
    @State private var index = 0
    @State private var scrollID: Int?
    @State private var hovering = false
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(Array(sites.enumerated()), id: \.offset) { i, site in
                        BigSiteCard(site: site, height: 190)
                            .containerRelativeFrame(.horizontal, count: 3, span: 1, spacing: 16)
                            .id(i)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 1)
            }
            .frame(height: 200)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollID)
            .onHover { hovering = $0 }
            .onChange(of: scrollID) { _, v in if let v { index = v } }
            .onReceive(timer) { _ in
                guard !hovering, sites.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.6)) { scrollID = (index + 1) % sites.count }
            }

            HStack(spacing: 7) {
                ForEach(0..<sites.count, id: \.self) { i in
                    Capsule().fill(i == index ? Theme.accent : Theme.border)
                        .frame(width: i == index ? 20 : 6, height: 6)
                        .onTapGesture { withAnimation(Theme.smooth) { scrollID = i } }
                }
            }
        }
        .onAppear { scrollID = 0 }
    }
}

/// Large platform card with the official logo. Opens the site in the browser.
struct BigSiteCard: View {
    let site: SupportedSite
    var height: CGFloat = 190
    @State private var hover = false
    private var brand: Color { BrandColors.color(site.name) }

    var body: some View {
        Button { if let u = URL(string: "https://\(site.domain)") { NSWorkspace.shared.open(u) } } label: {
            VStack(alignment: .leading, spacing: 10) {
                logo
                Spacer(minLength: 0)
                Text(site.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(site.domain).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(.ultraThinMaterial))
            .background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(Theme.surface.opacity(0.4)))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(brand)
                    .padding(8).background(Circle().fill(brand.opacity(0.14))).padding(12)
                    .opacity(hover ? 1 : 0.4)
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).strokeBorder(brand.opacity(hover ? 0.55 : 0.14), lineWidth: 1))
            .shadow(color: brand.opacity(hover ? 0.28 : 0), radius: 18, y: 8)
            .scaleEffect(hover ? 1.02 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hover)
        .help(site.domain)
    }

    @ViewBuilder private var logo: some View {
        if let img = site.logoImage {
            Image(nsImage: img).resizable().scaledToFit().frame(width: 54, height: 54)
        } else {
            Image(systemName: site.symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(brand))
        }
    }
}

/// A searchable chip that magnifies (Dock-style) on hover.
struct SiteChip: View {
    let name: String
    @State private var hover = false
    var body: some View {
        Text(name)
            .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textPrimary)
            .lineLimit(1).truncationMode(.middle)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hover ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Theme.surface.opacity(0.5))))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(hover ? Theme.accent.opacity(0.5) : Theme.border, lineWidth: 1))
            .scaleEffect(hover ? 1.18 : 1)
            .shadow(color: .black.opacity(hover ? 0.22 : 0), radius: 10, y: 4)
            .zIndex(hover ? 5 : 0)
            .onHover { hover = $0 }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hover)
            .help(name)
    }
}
