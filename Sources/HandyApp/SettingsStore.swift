import Foundation
import HandyCore
import os

/// Reads and writes `settings.json` in Handy's data folder.
enum SettingsStore {
    static var url: URL { AppPaths.data.appending(path: "settings.json") }
    private static let log = Logger(subsystem: "dev.handy", category: "settings")
    /// Before settings.json existed, the camera choice lived in UserDefaults.
    static let legacyCameraKey = "cameraID"

    static func load(defaults: UserDefaults = .standard) -> UserSettings {
        if let data = try? Data(contentsOf: url),
            let settings = try? JSONDecoder().decode(UserSettings.self, from: data)
        {
            return settings
        }
        var settings = UserSettings()
        if let camera = defaults.string(forKey: legacyCameraKey) {
            settings.cameraID = camera
            if (try? save(settings)) != nil { defaults.removeObject(forKey: legacyCameraKey) }
        }
        return settings
    }

    static func save(_ settings: UserSettings) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
