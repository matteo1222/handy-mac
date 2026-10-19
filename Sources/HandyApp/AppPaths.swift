import Foundation

/// Where Handy keeps its own files. `HANDY_DATA_DIR` overrides it, so verification runs never
/// write into the user's data.
enum AppPaths {
    static var data: URL {
        if let override = ProcessInfo.processInfo.environment["HANDY_DATA_DIR"], !override.isEmpty {
            return URL(filePath: override)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Handy")
    }

    static var calibration: URL { data.appending(path: "calibration.json") }
    static var recordings: URL { data.appending(path: "Recordings") }
    static var falsePositives: URL { data.appending(path: "FalsePositives") }
    static var accidentalActionLog: URL { data.appending(path: "accidental-actions.log") }
}
