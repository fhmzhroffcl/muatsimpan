import Foundation
import Combine
import Sparkle

/// Thin wrapper around Sparkle's standard updater. Sparkle auto-checks on launch
/// (via the `SUEnableAutomaticChecks` / `SUFeedURL` keys added in bundle.sh) and
/// this exposes a manual "Check for Updates…" entry point for the app menu and
/// the About screen. Updates are EdDSA-signed DMGs published to GitHub Releases;
/// the public key lives in Info.plist as `SUPublicEDKey`.
final class UpdaterController: ObservableObject {
    static let shared = UpdaterController()

    @Published var canCheckForUpdates = false
    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    /// Show the update UI (or "you're up to date") on demand.
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
