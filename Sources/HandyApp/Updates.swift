import Foundation
import ServiceManagement
import Sparkle

/// Sparkle updates. The update check is the only network call in Handy, and it runs only in builds
/// that carry a feed URL and an EdDSA public key (release builds); development builds never start it.
@MainActor
final class Updates {
    private let controller: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        let configured =
            bundle.object(forInfoDictionaryKey: "SUFeedURL") != nil
            && bundle.object(forInfoDictionaryKey: "SUPublicEDKey") != nil
        controller =
            configured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) : nil
    }

    var isAvailable: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}

/// Open at login, off until the user turns it on.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
