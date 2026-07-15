import SwiftUI

private struct GuideVisibilityKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// The guide is a scroll-led tour of the real Musim flow. Each chapter mirrors
/// a state the user sees in the app, while its geometry drives the reveal and
/// the progress line rather than relying on a one-time onAppear animation.
struct PanduanView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeChapter = 0
    @State private var revealed: Set<Int> = []
    @State private var quality = "1080p"
    @State private var mediaKind = 0

    private let chapters: [(String, String, String, String, String, String)] = [
        ("01", "Mula dengan koleksi anda", "Start with your collection", "Pustaka menjadi tempat utama untuk semua media yang anda simpan.", "Library is the home for everything you save.", "square.stack.3d.up.fill"),
        ("02", "Tambah ke arkib", "Add to archive", "Bila anda mahu menambah sesuatu, pilih Tambah ke arkib.", "When you want to add something, choose Add to archive.", "plus.circle.fill"),
        ("03", "Tampal pautan", "Paste a link", "Letakkan pautan video atau audio di ruang simpanan.", "Place a video or audio link in the save field.", "link"),
        ("04", "Semak media", "Review the media", "Musim membaca tajuk, jenis media, format, dan pilihan yang tersedia.", "Musim reads the title, media type, format, and available choices.", "doc.text.magnifyingglass"),
        ("05", "Pilih video atau audio", "Choose video or audio", "Pilih bentuk yang sesuai dengan cara anda mahu menyimpan media itu.", "Choose the form that fits how you want to keep it.", "slider.horizontal.3"),
        ("06", "Pilih kualiti dan format", "Choose quality and format", "Semak pilihan kualiti dan format sebelum menyimpan.", "Review quality and format options before saving.", "rectangle.3.group"),
        ("07", "Tetapkan lokasi simpanan", "Set the save location", "Fail disimpan terus dalam folder yang anda pilih pada peranti.", "Files go directly into the folder you choose on your device.", "folder.fill"),
        ("08", "Simpan ke arkib", "Save to archive", "Tekan Simpan. Musim akan menguruskan proses dan menunjukkan kemajuan.", "Press Save. Musim handles the process and shows its progress.", "archivebox.fill"),
        ("09", "Pantau aktiviti", "Follow activity", "Aktiviti menunjukkan simpanan yang sedang berjalan dan yang sudah selesai.", "Activity shows saves in progress and those that are complete.", "square.stack.3d.up"),
        ("10", "Cari dalam Pustaka", "Find it in Library", "Media baharu muncul bersama saiz, format, tarikh arkib, dan sumbernya.", "New media appears with its size, format, archive date, and source.", "magnifyingglass"),
        ("11", "Main atau sunting dalam app", "Play or edit in the app", "Buka media dalam pemain terbina dalam atau editor untuk kerja seterusnya.", "Open media in the built-in player or editor for the next step.", "play.rectangle.fill"),
        ("12", "Simpanan anda, kawalan anda", "Your archive, your control", "Fail kekal pada peranti dan dalam folder yang anda miliki.", "Files stay on your device and in a folder you own.", "checkmark.seal.fill")
    ]
    private let sources = ["YT", "FB", "TT", "IG", "X", "SC", "VM", "RD"]

    private var isMalay: Bool { settings.language == .malay }
    private var progress: CGFloat { CGFloat(activeChapter + 1) / CGFloat(chapters.count) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                progressHeader
                chapterRail
                supportedSources
                useItWell
            }
            .padding(.horizontal, 44)
            .padding(.top, 54)
            .padding(.bottom, 110)
        }
        .coordinateSpace(name: "guideScroll")
        .background(Theme.bg)
        .onPreferenceChange(GuideVisibilityKey.self) { positions in
            guard !positions.isEmpty else { return }
            let candidates = positions.filter { $0.value > -220 && $0.value < 520 }
            guard let next = candidates.min(by: { abs($0.value - 150) < abs($1.value - 150) })?.key else { return }
            let changed = next != activeChapter
            activeChapter = next
            if reduceMotion {
                revealed = Set(0...next)
            } else if changed {
                withAnimation(.spring(response: 0.65, dampingFraction: 0.86)) {
                    revealed.formUnion(0...next)
                }
            }
        }
        .onAppear { revealed = reduceMotion ? Set(0..<chapters.count) : [0] }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(isMalay ? "PANDUAN" : "GUIDE", systemImage: "book.closed.fill")
                .font(.system(size: 11, weight: .bold)).tracking(1.8).foregroundStyle(Theme.accent)
            Text(isMalay ? "Dari pautan ke simpanan milik anda." : "From a link to media you own.")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(isMalay
                 ? "Ikuti perjalanan penuh Musim. Setiap bab akan hidup apabila anda scroll—daripada ruang Tambah ke arkib hingga pemain, editor, dan Pustaka."
                 : "Follow the full Musim journey. Each chapter comes alive as you scroll—from Add to archive to the player, editor, and Library.")
                .font(.system(size: 16)).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 720, alignment: .leading)
            HStack(spacing: 10) {
                badge(isMalay ? "12 bab interaktif" : "12 interactive chapters", symbol: "sparkles")
                badge(isMalay ? "Ikut scroll" : "Scroll-led", symbol: "arrow.down")
                badge(isMalay ? "Dalam app" : "Inside the app", symbol: "square.stack")
            }
        }
        .padding(.bottom, 40)
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(isMalay ? "JELAJAHKAN ALIRAN" : "EXPLORE THE FLOW")
                    .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(activeChapter + 1) / \(chapters.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.accent)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border).frame(height: 4)
                    Capsule().fill(Theme.accentGradient).frame(width: max(8, proxy.size.width * progress), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.bottom, 28)
    }

    private var chapterRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(index <= activeChapter ? Theme.accent : Theme.surface)
                            Text(chapter.0).font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(index <= activeChapter ? Color.white : Theme.textSecondary)
                        }
                        .frame(width: 34, height: 34)
                        if index < chapters.count - 1 {
                            Rectangle().fill(index < activeChapter ? Theme.accent : Theme.border)
                                .frame(width: 2, height: 22)
                                .scaleEffect(y: index < activeChapter || reduceMotion ? 1 : 0.2, anchor: .top)
                                .animation(.easeOut(duration: 0.55), value: activeChapter)
                        }
                    }
                    chapterCard(index: index, chapter: chapter)
                }
                .id(index)
                .background(GuideVisibilityReader(index: index))
            }
        }
    }

    private func chapterCard(index: Int, chapter: (String, String, String, String, String, String)) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: chapter.5).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(isMalay ? chapter.1 : chapter.2).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    Text(isMalay ? chapter.3 : chapter.4).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            chapterDemo(index)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous).fill(Theme.surface.opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: Theme.rMd, style: .continuous).strokeBorder(index == activeChapter ? Theme.accent.opacity(0.58) : Theme.border, lineWidth: index == activeChapter ? 1.5 : 1))
        .shadow(color: index == activeChapter ? Theme.accent.opacity(0.08) : .clear, radius: 22, y: 8)
        .opacity(reduceMotion || revealed.contains(index) ? 1 : 0.22)
        .offset(y: reduceMotion || revealed.contains(index) ? 0 : 32)
        .scaleEffect(reduceMotion || revealed.contains(index) ? 1 : 0.985)
        .animation(reduceMotion ? nil : .spring(response: 0.66, dampingFraction: 0.84), value: revealed)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: activeChapter)
    }

    @ViewBuilder
    private func chapterDemo(_ index: Int) -> some View {
        GuideAppSurface {
            switch index {
            case 0: libraryHomeDemo
            case 1: addArchiveDemo
            case 2: pasteDemo
            case 3: inspectDemo
            case 4: kindDemo
            case 5: qualityDemo
            case 6: folderDemo
            case 7: savingDemo
            case 8: activityDemo
            case 9: libraryMetaDemo
            case 10: playerEditorDemo
            default: ownershipDemo
            }
        }
    }

    private var libraryHomeDemo: some View {
        HStack(spacing: 14) {
            miniSidebar(active: 0)
            VStack(alignment: .leading, spacing: 10) {
                Text(isMalay ? "Pustaka" : "Library").font(.system(size: 21, weight: .bold)).foregroundStyle(Theme.textPrimary)
                Text(isMalay ? "Koleksi anda" : "Your collection").font(.caption).foregroundStyle(Theme.textSecondary)
                coverStrip(count: 5)
                Text(isMalay ? "0 item · 0 B dalam simpanan anda" : "0 items · 0 B in your archive").font(.caption2).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var addArchiveDemo: some View {
        HStack {
            Image(systemName: "archivebox.fill").foregroundStyle(Theme.accent)
            Text(isMalay ? "+ Tambah ke arkib" : "+ Add to archive").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "arrow.right").foregroundStyle(Theme.accent)
        }
        .padding(14).background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg))
    }

    private var pasteDemo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isMalay ? "Tambah media ke arkib anda" : "Add media to your archive").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 9) {
                Image(systemName: "link").foregroundStyle(Theme.accent)
                Text(isMalay ? "Tampal pautan media…" : "Paste a media link…").foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(isMalay ? "Simpan" : "Save").font(.caption.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(Theme.accent))
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
        }
    }

    private var inspectDemo: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8).fill(Theme.accent.opacity(0.25)).frame(width: 82, height: 52).overlay(Image(systemName: "film").foregroundStyle(Theme.accent))
            VStack(alignment: .leading, spacing: 4) {
                Text(isMalay ? "Media ditemui" : "Media found").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary)
                Text("Video · 1080p · MP4 · 74 MB").font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
        }
    }

    private var kindDemo: some View {
        HStack(spacing: 8) {
            ForEach([isMalay ? "Video" : "Video", isMalay ? "Audio" : "Audio"], id: \.self) { label in
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(label == (isMalay ? "Video" : "Video") ? Theme.accent : Theme.surface))
            }
            Spacer()
            Image(systemName: "waveform").foregroundStyle(Theme.accent)
        }
    }

    private var qualityDemo: some View {
        HStack(spacing: 8) {
            Text(isMalay ? "Kualiti" : "Quality").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
            ForEach(["1080p", "720p", "480p"], id: \.self) { value in
                Button(value) { quality = value }.buttonStyle(.plain).font(.caption.weight(.semibold))
                    .foregroundStyle(quality == value ? Color.white : Theme.textSecondary)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(Capsule().fill(quality == value ? Theme.accent : Theme.surface))
            }
            Spacer()
            Text("MP4").font(.caption2.monospaced()).foregroundStyle(Theme.accent)
        }
    }

    private var folderDemo: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill").font(.title3).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(isMalay ? "Lokasi simpanan" : "Save location").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary)
                Text(settings.downloadPath).font(.caption2.monospaced()).foregroundStyle(Theme.textSecondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "checkmark").foregroundStyle(Theme.accent)
        }
    }

    private var savingDemo: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Image(systemName: "archivebox.fill").foregroundStyle(Theme.accent); Text(isMalay ? "Sedang menyimpan" : "Saving").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary); Spacer(); Text("68%").font(.caption.monospacedDigit()).foregroundStyle(Theme.accent) }
            GeometryReader { proxy in
                Capsule().fill(Theme.border).overlay(alignment: .leading) { Capsule().fill(Theme.accentGradient).frame(width: proxy.size.width * 0.68) }
            }.frame(height: 6)
            Text(isMalay ? "Fail akan masuk ke folder pilihan anda" : "The file will go to your chosen folder").font(.caption2).foregroundStyle(Theme.textSecondary)
        }
    }

    private var activityDemo: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill").foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 3) { Text(isMalay ? "Aktiviti" : "Activity").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary); Text(isMalay ? "Simpanan selesai" : "Save complete").font(.caption2).foregroundStyle(Theme.textSecondary) }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
        }
    }

    private var libraryMetaDemo: some View {
        HStack(spacing: 8) {
            coverStrip(count: 3)
            VStack(alignment: .leading, spacing: 4) { Text(isMalay ? "Diarkibkan hari ini" : "Archived today").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary); Text("MP4 · 1080p · 74 MB").font(.caption2).foregroundStyle(Theme.textSecondary); Text(isMalay ? "dalam simpanan anda" : "in your archive").font(.caption2).foregroundStyle(Theme.accent) }
        }
    }

    private var playerEditorDemo: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 7).fill(Theme.accent.opacity(0.24)).frame(height: 72).overlay(Image(systemName: "play.fill").foregroundStyle(Theme.accent))
            VStack(alignment: .leading, spacing: 6) { Text(isMalay ? "Pemain terbina dalam" : "Built-in player").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary); Text(isMalay ? "Main tanpa keluar dari Musim" : "Play without leaving Musim").font(.caption2).foregroundStyle(Theme.textSecondary); RoundedRectangle(cornerRadius: 3).fill(Theme.accent).frame(height: 4) }
            VStack(spacing: 5) { Image(systemName: "slider.horizontal.3").foregroundStyle(Theme.accent); Text(isMalay ? "Editor" : "Editor").font(.caption2).foregroundStyle(Theme.textSecondary) }
        }
    }

    private var ownershipDemo: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 4) { Text(isMalay ? "Fail disimpan pada peranti anda" : "Files saved on your device").font(.caption.weight(.bold)).foregroundStyle(Theme.textPrimary); Text(isMalay ? "Anda tentukan lokasi dan kawalan simpanan." : "You choose the location and control the archive.").font(.caption2).foregroundStyle(Theme.textSecondary) }
        }
    }

    private var supportedSources: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(isMalay ? "Sumber Disokong" : "Supported Sources", icon: "square.stack.3d.up.fill")
            Text(isMalay ? "Kod neutral ini menunjukkan keserasian luas tanpa mempromosikan mana-mana platform." : "These neutral codes signal broad compatibility without promoting any platform.")
                .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
            FlowLayout(spacing: 8) {
                ForEach(sources, id: \.self) { source in
                    Text(source).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.textPrimary).padding(.horizontal, 12).padding(.vertical, 7).background(Capsule().fill(Theme.surface)).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                }
                Text(isMalay ? "… dan banyak lagi" : "… and many more").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent).padding(.horizontal, 12).padding(.vertical, 7)
            }
        }
        .padding(.top, 58).padding(.bottom, 42)
    }

    private var useItWell: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(isMalay ? "Guna dengan betul" : "Use it well", icon: "heart.text.square.fill")
            Text(isMalay
                 ? "Arkibkan kandungan milik anda atau yang memang anda berhak simpan—seperti muat naik sendiri, bahan awam atau Creative Commons, dan salinan yang dilesenkan untuk anda. Musim menyimpan fail terus ke peranti; anda memiliki dan mengawal simpanan itu."
                 : "Archive content you own or are entitled to keep—your own uploads, public or Creative Commons material, and backups you are licensed for. Musim saves files directly to your device; you own and control that archive.")
                .font(.system(size: 14)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(22).background(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).fill(Theme.accentSoft.opacity(0.45))).overlay(RoundedRectangle(cornerRadius: Theme.rLg, style: .continuous).strokeBorder(Theme.accent.opacity(0.25), lineWidth: 1))
    }

    private func badge(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary).padding(.horizontal, 10).padding(.vertical, 7).background(Capsule().fill(Theme.surface)).overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.textPrimary)
    }

    private func miniSidebar(active: Int) -> some View {
        VStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 6).fill(Color.black).frame(width: 30, height: 30)
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4).fill(index == active ? Theme.accent : Theme.surface).frame(width: 30, height: index == active ? 24 : 20)
            }
            Spacer(minLength: 0)
        }.frame(width: 34)
    }

    private func coverStrip(count: Int) -> some View {
        HStack(spacing: 6) { ForEach(0..<count, id: \.self) { index in RoundedRectangle(cornerRadius: 5).fill(index == 0 ? Theme.accent : Theme.surfaceHover).frame(width: 48, height: 56) } }
    }
}

private struct GuideVisibilityReader: View {
    let index: Int
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: GuideVisibilityKey.self, value: [index: proxy.frame(in: .named("guideScroll")).minY])
        }
        .frame(height: 0)
    }
}

private struct GuideAppSurface<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 7).fill(Theme.bg).frame(width: 42).overlay(alignment: .top) {
                VStack(spacing: 9) { Circle().fill(Theme.accent).frame(width: 10, height: 10); ForEach(0..<5, id: \.self) { _ in RoundedRectangle(cornerRadius: 3).fill(Theme.surface).frame(width: 23, height: 8) } }.padding(.top, 14)
            }
            VStack(alignment: .leading, spacing: 9) { content }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 10).fill(Theme.bg)).overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
    }
}
