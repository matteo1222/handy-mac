import Foundation
import HandyCore

/// Per-day usage counts in `<data>/usage.json`. Counts only, never content; nothing leaves the Mac.
enum UsageStore {
    static var url: URL { AppPaths.data.appending(path: "usage.json") }

    static func load() -> [String: UsageStats] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: UsageStats].self, from: data)) ?? [:]
    }

    /// Adds `stats` to today's entry.
    static func add(_ stats: UsageStats, on date: Date = Date()) throws {
        guard stats != UsageStats() else { return }
        var days = load()
        days[day(date), default: UsageStats()].merge(stats)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(days).write(to: url, options: .atomic)
    }

    static func day(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}
