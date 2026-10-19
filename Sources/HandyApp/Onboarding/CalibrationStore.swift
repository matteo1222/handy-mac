import Foundation
import HandyCore

/// Calibration lives in Application Support as plain JSON numbers.
enum CalibrationStore {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Handy/calibration.json")
    }

    static func load() -> Calibration? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Calibration.self, from: data)
    }

    static func save(_ calibration: Calibration) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(calibration).write(to: url, options: .atomic)
    }
}
