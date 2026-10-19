import ArgumentParser
import Foundation
import HandyCore
import HandyReplay

struct BenchClick: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bench-click",
        abstract: "A/B the click gesture (thumb-index pinch vs index dip) on synthetic clips.",
        discussion: """
            Reports click recall, recall with dim fingertips (front-camera occlusion) and false clicks per hour of
            engaged pointing with fidgets. Synthetic only: recorded clips (TASK-17) are what the decision rests on.
            """)

    @Option(help: "Deliberate click clips per gesture.")
    var clips = 60

    @Option(help: "Minutes of engaged pointing per gesture.")
    var minutes = 30.0

    @Option(help: "Where to write the report.")
    var report = "docs/click-ab-report.json"

    func run() throws {
        let results = ClickGesture.allCases.map { ClickBench.run($0, clips: clips, engagedMinutes: minutes) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (encoder.encode(results) + Data("\n".utf8)).write(to: URL(filePath: report))
        try printJSON(results)
    }
}
