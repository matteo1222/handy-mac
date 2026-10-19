import Foundation
import HandyCore
import HandyReplay

/// Every oops: undo, keep the landmarks that led to the mistake as a false-positive sample (numbers
/// only), and append a line to a log the user can open. The samples feed the regression corpus.
struct OopsLog {
    struct Entry: Codable {
        var time: Date
        /// What Handy did that the user undid.
        var undid: String?
        var sample: String?
    }

    /// Seconds of landmarks kept before the wag, and the wag's own length left out of the sample.
    static let keep = 6.0
    static let wagLength = 1.3

    /// Writes the sample and the log line; returns the entry.
    @discardableResult
    static func record(frames: [LandmarkFrame], at t: Double, undid: String?, now: Date = Date()) throws -> Entry {
        let window = frames.filter { $0.t >= t - keep && $0.t <= t - wagLength }
        var sample: String?
        if let first = window.first {
            let folder = AppPaths.falsePositives
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
                .replacingOccurrences(of: ":", with: "")
            let url = folder.appending(path: "\(name).lmk")
            let frames = window.map { frame in
                var shifted = frame
                shifted.t = frame.t - first.t
                return shifted
            }
            let duration = frames.last?.t ?? 0
            let stream = LandmarkStream(
                header: .init(
                    source: "oops", labels: [.init(start: 0, end: duration + 0.001, name: "none")],
                    meta: ["undid": undid ?? "unknown"]),
                frames: frames)
            try stream.write(to: url)
            sample = url.path(percentEncoded: false)
        }
        let entry = Entry(time: now, undid: undid, sample: sample)
        try append(entry)
        return entry
    }

    static func append(_ entry: Entry) throws {
        let url = AppPaths.accidentalActionLog
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let line = try encoder.encode(entry) + Data("\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: url)
        }
    }

    /// How many oopses are in the log.
    static func count() -> Int {
        guard let text = try? String(contentsOf: AppPaths.accidentalActionLog, encoding: .utf8) else { return 0 }
        return text.split(separator: "\n").count
    }
}
