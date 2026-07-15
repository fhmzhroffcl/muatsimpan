import SwiftUI
import AppKit
import AVFoundation

/// First-run setup for a clean shared install.
struct OnboardingView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var step = 0
    @State private var name = ""
    @State private var sampleNote = "Idea pertama: simpan video rujukan dalam folder platform, kemudian tambah nota kecil supaya senang jumpa balik."
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioMuted = false
    @State private var audioAvailable = false
    @FocusState private var nameFocused: Bool

    private let steps = 7
    private var my: Bool { settings.language == .malay }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedNote: String { sampleNote.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var continueDisabled: Bool {
        (step == 2 && trimmedName.isEmpty) || (step == 5 && trimmedNote.isEmpty)
    }

    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.8)

            VStack(spacing: 0) {
                Spacer()

                Group {
                    switch step {
                    case 0: language
                    case 1: welcome
                    case 2: askName
                    case 3: essentials
                    case 4: naming
                    case 5: noteSetup
                    default: support
                    }
                }
                .frame(maxWidth: 620)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)

                Spacer()

                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(0..<steps, id: \.self) { i in
                            Capsule()
                                .fill(i == step ? Theme.accent : Color.secondary.opacity(0.3))
                                .frame(width: i == step ? 26 : 8, height: 8)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)

                    HStack {
                        if step > 0 {
                            Button(my ? "Kembali" : "Back") {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step -= 1 }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if step == steps - 1 {
                            Button(my ? "Langkau" : "Skip") { finish() }
                                .buttonStyle(GlassButtonStyle())
                        }
                        Button(step == steps - 1 ? (my ? "Mula Guna Musim" : "Start Musim") : (my ? "Teruskan" : "Continue")) {
                            advance()
                        }
                        .buttonStyle(ExpressiveButtonStyle())
                        .disabled(continueDisabled)
                    }
                    .frame(maxWidth: 620)
                }
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 60)

            onboardingMuteButton
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .ignoresSafeArea()
        .onAppear {
            name = settings.userName
            startOnboardingAudio()
        }
        .onDisappear { stopOnboardingAudio() }
    }

    private func advance() {
        if step == 2 { settings.userName = trimmedName }
        if step == steps - 1 {
            finish()
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step += 1 }
            if step == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { nameFocused = true }
            }
        }
    }

    private func finish() {
        if step >= 2 { settings.userName = trimmedName }
        settings.ensureDownloadDirectory()
        saveSampleNote()
        LibraryStore.shared.refresh()
        stopOnboardingAudio()
        withAnimation { settings.onboardingCompleted = true }
    }

    private var onboardingMuteButton: some View {
        Button {
            audioMuted.toggle()
            audioPlayer?.volume = audioMuted ? 0 : 0.35
        } label: {
            Image(systemName: audioMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(audioAvailable ? 0.82 : 0.35))
                .frame(width: 34, height: 34)
                .background(Circle().fill(.black.opacity(0.28)))
                .overlay(Circle().strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(my ? "Senyapkan audio onboarding" : "Mute onboarding audio")
        .opacity(0.72)
        .disabled(!audioAvailable)
    }

    private func startOnboardingAudio() {
        guard audioPlayer == nil else { return }
        guard let url = onboardingAudioURL() else {
            audioAvailable = false
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = audioMuted ? 0 : 0.35
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            audioAvailable = true
        } catch {
            audioAvailable = false
        }
    }

    private func stopOnboardingAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func onboardingAudioURL() -> URL? {
        for ext in ["MP3", "mp3", "m4a", "wav", "aac", "caf"] {
            if let url = Bundle.main.url(forResource: "musim", withExtension: ext, subdirectory: "audio") {
                return url
            }
            if let url = Bundle.main.url(forResource: "onboarding-audio", withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private var language: some View {
        VStack(spacing: 20) {
            MusimLogo(size: 76)
            VStack(spacing: 8) {
                Text(my ? "Pilih Bahasa" : "Choose Language")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(my ? "Pilih bahasa untuk Musim. Anda boleh tukar kemudian di Tetapan." : "Choose the language for Musim. You can change this later in Settings.")
                    .font(.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Picker("", selection: $settings.language) {
                ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 320)
            .onChange(of: settings.language) { _, _ in GreetingEngine.shared.refresh() }
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            MusimLogo(size: 76)
            Text(my ? "Selamat Datang ke Musim" : "Welcome to Musim")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(my
                 ? "Arkib + Simpan. Tampal pautan video atau audio, pilih kualiti, dan biar Musim susun fail anda dengan kemas."
                 : "Archive + Save. Paste video or audio links, pick quality, and let Musim organize your files neatly.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var askName: some View {
        VStack(spacing: 18) {
            Image(systemName: "hand.wave.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent)
            Text(my ? "Apa nama anda?" : "What should we call you?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            TextField(my ? "Nama anda" : "Your name", text: $name)
                .textFieldStyle(.plain)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quaternary.opacity(0.5)))
                .focused($nameFocused)
                .onSubmit { if !name.trimmingCharacters(in: .whitespaces).isEmpty { advance() } }
        }
    }

    private var essentials: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(my ? "Tetapan Asas" : "The essentials")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(my ? "Musim akan cipta folder YouTube, TikTok, Facebook dan Instagram secara automatik." : "Musim will create YouTube, TikTok, Facebook and Instagram folders automatically.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 14) {
                settingRow(icon: "folder.fill", title: my ? "Simpan media di" : "Save media to") {
                    Button {
                        pickFolder()
                    } label: {
                        HStack(spacing: 6) {
                            Text(URL(fileURLWithPath: settings.downloadPath).lastPathComponent)
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                settingRow(icon: "square.stack.3d.up.fill",
                           title: my ? "Susun ikut platform" : "Organize by platform",
                           subtitle: my ? "Sumber baharu akan dapat folder sendiri." : "New sources get their own folder.") {
                    Toggle("", isOn: $settings.organizeByPlatform).labelsHidden().toggleStyle(.switch)
                }

                settingRow(icon: "person.crop.square.stack.fill",
                           title: my ? "Subfolder pencipta" : "Creator subfolders",
                           subtitle: my ? "Jika hidup, folder pencipta duduk di dalam folder platform." : "When on, creator folders sit inside the platform folder.") {
                    Toggle("", isOn: $settings.channelSubfolders).labelsHidden().toggleStyle(.switch)
                }

                folderPreview

                settingRow(icon: "key.fill",
                           title: my ? "Kuki pelayar" : "Browser cookies",
                           subtitle: my ? "Pilihan untuk video peribadi atau perlu log masuk." : "Optional for private or login-required videos.") {
                    Picker("", selection: $settings.browserForCookies) {
                        ForEach(AppSettings.browsers, id: \.self) { Text(browserLabel($0)).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                settingRow(icon: "sparkles", title: my ? "Kualiti lalai" : "Default quality") {
                    Picker("", selection: $settings.oneClickQuality) {
                        ForEach(QualityPreset.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
            }
            .padding(18)
            .glassCard(radius: Theme.rLg)
        }
    }

    private var folderPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(my ? "Struktur folder" : "Folder structure")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                ForEach(AppSettings.defaultPlatformFolders, id: \.self) { folder in
                    Label(folder, systemImage: "folder.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accent.opacity(0.14)))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            Text(my
                 ? "Contoh: YouTube / Nama Pencipta / Tajuk Video.mp4"
                 : "Example: YouTube / Creator Name / Video Title.mp4")
                .font(.caption.monospaced())
                .foregroundStyle(Theme.accent)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.05)))
    }

    private var naming: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(my ? "Penamaan Fail" : "File naming")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(my ? "Gunakan tajuk video, atau bina nama fail dengan awalan, tarikh, nombor dan akhiran." : "Use video titles, or compose filenames with prefix, date, counter and suffix.")
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 14) {
                settingRow(icon: "textformat", title: my ? "Namakan fail dari tajuk video" : "Auto-name files from video title") {
                    Toggle("", isOn: $settings.autoNaming).labelsHidden().toggleStyle(.switch)
                }
                settingRow(icon: "wand.and.stars", title: my ? "Penamaan lanjutan" : "Advanced naming",
                           subtitle: my ? "Awalan, tarikh, nombor dan akhiran." : "Prefix, date, counter and suffix.") {
                    Toggle("", isOn: $settings.advancedNaming).labelsHidden().toggleStyle(.switch)
                        .disabled(!settings.autoNaming)
                }
                HStack(spacing: 8) {
                    TextField(my ? "Awalan" : "Prefix", text: $settings.namePrefix)
                    TextField(my ? "Akhiran" : "Suffix", text: $settings.nameSuffix)
                }
                .textFieldStyle(.roundedBorder)
                .disabled(!settings.autoNaming || !settings.advancedNaming)

                HStack(spacing: 10) {
                    Picker(my ? "Tarikh" : "Date", selection: $settings.nameDate) {
                        Text(my ? "Tiada" : "None").tag("none")
                        Text("YYYYMMDD").tag("%Y%m%d")
                        Text("YYYY-MM-DD").tag("%Y-%m-%d")
                    }
                    .frame(width: 190)
                    Toggle(my ? "Nombor turutan" : "Counter", isOn: $settings.nameCounter)
                        .disabled(!settings.autoNaming || !settings.advancedNaming)
                }
                .disabled(!settings.autoNaming || !settings.advancedNaming)

                HStack {
                    Text(my ? "Contoh:" : "Example:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(settings.namingExample())
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
            }
            .padding(18)
            .glassCard(radius: Theme.rLg)
        }
    }

    private var noteSetup: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(my ? "Nota Pertama" : "First note")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(my ? "Tulis satu nota contoh. Musim akan simpan dalam Pustaka supaya pengguna terus nampak cara nota lekat berfungsi." : "Write one sample note. Musim saves it in the Library so the sticky-note flow is clear from the start.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.yellow.opacity(0.88))
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Circle().fill(.orange.opacity(0.55)).frame(width: 8, height: 8)
                                    RoundedRectangle(cornerRadius: 3).fill(.black.opacity(0.18)).frame(width: 76, height: 7)
                                    Spacer()
                                }
                                Text(trimmedNote.isEmpty ? (my ? "Nota contoh..." : "Sample note...") : trimmedNote)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.72))
                                    .lineLimit(5)
                            }
                            .padding(14)
                        }
                        .frame(width: 190, height: 132)
                        .rotationEffect(.degrees(-1.5))
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

                    TextEditor(text: $sampleNote)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(height: 132)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.quaternary.opacity(0.42)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.accent.opacity(0.28), lineWidth: 1))
                }

                Label(my ? "Nota ini akan diletakkan pada folder YouTube dalam Pustaka." : "This note will be pinned to the YouTube folder in the Library.",
                      systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(18)
            .glassCard(radius: Theme.rLg)
        }
    }

    private var support: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            VStack(spacing: 6) {
                Text(my ? "Sokong Musim" : "Support Musim")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(my ? "Imbas QR DuitNow jika anda mahu sokong pembangunan app ini. Boleh juga langkau dulu." : "Scan the DuitNow QR if you want to support the app. You can skip this for now.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            DuitNowQR()
                .frame(width: 230, height: 230)
            Text(my ? "Imbas dengan aplikasi bank Malaysia." : "Scan with any Malaysian banking app.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func settingRow<Content: View>(icon: String, title: String, subtitle: String? = nil, @ViewBuilder control: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium).foregroundStyle(Theme.textPrimary)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            control()
        }
    }

    private func browserLabel(_ browser: String) -> String {
        if browser == "none" { return my ? "Dimatikan" : "Off" }
        if browser == "auto" { return my ? "Pelayar lalai" : "Default browser" }
        return browser.capitalized
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: settings.downloadPath)
        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadPath = url.path
            settings.ensureDownloadDirectory()
        }
    }

    private func saveSampleNote() {
        let text = trimmedNote
        guard !text.isEmpty else { return }
        settings.ensureDownloadDirectory()

        let root = URL(fileURLWithPath: settings.downloadPath)
        let folder = root.appendingPathComponent("YouTube", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let entry = LibraryEntry(id: folder.path,
                                 url: folder,
                                 name: folder.lastPathComponent,
                                 isFolder: true,
                                 size: 0,
                                 modified: Date(),
                                 isMedia: false)
        let library = LibraryStore.shared
        if !library.notes(for: entry).contains(where: { $0.text == text }) {
            _ = library.addNote(StickyNote(text: text, color: "yellow", size: .wide), for: entry)
        }

        let noteFile = folder.appendingPathComponent("nota-contoh-musim.txt")
        if !FileManager.default.fileExists(atPath: noteFile.path) {
            try? text.write(to: noteFile, atomically: true, encoding: .utf8)
        }
    }
}
