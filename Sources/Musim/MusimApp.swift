import SwiftUI
import UserNotifications

@main
struct MusimApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var ytdlp = YtDlpManager.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView(onFinished: { withAnimation { showSplash = false } })
                        .transition(.opacity)
                } else if !settings.onboardingCompleted {
                    OnboardingView()
                        .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
                } else {
                    MainView()
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
            }
            .frame(minWidth: 1080, minHeight: 680)
            .preferredColorScheme(settings.appearance.colorScheme)
            .animation(.spring(response: 0.55, dampingFraction: 0.85), value: showSplash)
            .animation(.spring(response: 0.55, dampingFraction: 0.85), value: settings.onboardingCompleted)
            .task {
                ytdlp.checkOrInstall()
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
        .windowStyle(.hiddenTitleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
