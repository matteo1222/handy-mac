import ArgumentParser
import Foundation
import HandyCore
import HandyReplay

struct BenchCorpus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bench",
        abstract: "Measure false actions per hour, jitter and lag on a corpus against the stored baseline.",
        discussion: """
            The corpus is every .lmk under the given folders (labels in each header mark "none" footage and
            gestures; an unlabelled clip counts as no-gesture) plus a deterministic synthetic no-gesture corpus.
            Exits 1 when false actions rise at all, or jitter, lag or gesture recall regress past tolerance.
            The baseline only changes with --update-baseline, which prints the before/after diff.
            """)

    @Argument(help: "Corpus folders of .lmk files.")
    var corpus: [String] = []

    @Option(help: "Hours of synthetic no-gesture footage to add.")
    var syntheticHours = 2.0

    @Option(help: "Baseline JSON.")
    var baseline = "bench/baseline.json"

    @Flag(help: "Write this run as the new baseline (prints the before/after diff).")
    var updateBaseline = false

    @Option(help: "Allowed relative regression for jitter and lag.")
    var tolerance = 0.1

    func run() throws {
        var accumulator = Bench.Accumulator()
        var sources: [String] = []
        let chunk = 600.0
        let chunks = Int((syntheticHours * 3600 / chunk).rounded(.up))
        for index in 0..<chunks {
            let clip = NoGestureGenerator.clip(seconds: chunk, seed: UInt64(index + 1))
            let noise = SynthNoise(jitterPixels: 2, dropout: 0.02, confidenceLoss: 0.02, seed: UInt64(index + 1))
            accumulator.run(frames: { Synthesizer.forEachFrame(clip, noise: noise, $0) }, labels: [])
        }
        if chunks > 0 { sources.append("synthetic no-gesture, \(syntheticHours) h") }
        for folder in corpus {
            for url in try lmkFiles(in: folder) {
                let stream = try LandmarkStream(contentsOf: url)
                accumulator.run(frames: { stream.frames.forEach($0) }, labels: stream.header.labels)
                sources.append(url.path(percentEncoded: false))
            }
        }
        let hours = accumulator.noGestureSeconds / 3600
        let total = accumulator.falseActions.values.reduce(0, +)
        func round(_ value: Double, _ places: Double = 1000) -> Double { (value * places).rounded() / places }
        let report = BenchReport(
            noGestureHours: round(hours), falseActions: accumulator.falseActions,
            falseActionsPerHour: round(hours > 0 ? Double(total) / hours : 0), jitterPoints: round(Bench.jitter()),
            lagMilliseconds: round(Bench.lag(), 10),
            gestureRecall: accumulator.recallTotals.mapValues { _ in 0 }.merging(
                accumulator.recallTotals.map { name, count in
                    (name, round(Double(accumulator.recallHits[name] ?? 0) / Double(count)))
                }, uniquingKeysWith: { $1 }),
            processingMicroseconds: Summary(accumulator.timings).rounded(10), corpus: sources)

        let baselineURL = URL(filePath: baseline)
        let previous = try? JSONDecoder().decode(BenchReport.self, from: Data(contentsOf: baselineURL))
        let regressions = previous.map { regressionsAgainst($0, report) } ?? []
        if updateBaseline {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try FileManager.default.createDirectory(
                at: baselineURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (encoder.encode(report) + Data("\n".utf8)).write(to: baselineURL)
        }
        try printJSON(
            BenchOutcome(
                ok: updateBaseline || regressions.isEmpty, report: report, baseline: previous,
                regressions: regressions, baselineUpdated: updateBaseline,
                diff: updateBaseline ? previous.map { diffLines($0, report) } : nil))
        if !updateBaseline, !regressions.isEmpty { throw ExitCode.failure }
    }

    func regressionsAgainst(_ old: BenchReport, _ new: BenchReport) -> [String] {
        var found: [String] = []
        if new.falseActionsPerHour > old.falseActionsPerHour {
            found.append("false actions rose: \(old.falseActionsPerHour) -> \(new.falseActionsPerHour) per hour")
        }
        if new.jitterPoints > old.jitterPoints * (1 + tolerance) + 0.05 {
            found.append("jitter rose: \(old.jitterPoints) -> \(new.jitterPoints) pt")
        }
        if new.lagMilliseconds > old.lagMilliseconds * (1 + tolerance) + 5 {
            found.append("lag rose: \(old.lagMilliseconds) -> \(new.lagMilliseconds) ms")
        }
        for (gesture, recall) in old.gestureRecall where (new.gestureRecall[gesture] ?? 0) < recall {
            found.append("\(gesture) recall fell: \(recall) -> \(new.gestureRecall[gesture] ?? 0)")
        }
        return found
    }

    func diffLines(_ old: BenchReport, _ new: BenchReport) -> [String] {
        var lines = [
            "falseActionsPerHour: \(old.falseActionsPerHour) -> \(new.falseActionsPerHour)",
            "jitterPoints: \(old.jitterPoints) -> \(new.jitterPoints)",
            "lagMilliseconds: \(old.lagMilliseconds) -> \(new.lagMilliseconds)",
            "noGestureHours: \(old.noGestureHours) -> \(new.noGestureHours)",
        ]
        for kind in Set(old.falseActions.keys).union(new.falseActions.keys).sorted() {
            lines.append("falseActions.\(kind): \(old.falseActions[kind] ?? 0) -> \(new.falseActions[kind] ?? 0)")
        }
        return lines
    }

    func lmkFiles(in folder: String) throws -> [URL] {
        let root = URL(filePath: folder)
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "lmk" }.sorted { $0.path() < $1.path() }
    }
}

struct BenchOutcome: Encodable {
    let ok: Bool
    let report: BenchReport
    let baseline: BenchReport?
    let regressions: [String]
    let baselineUpdated: Bool
    let diff: [String]?
}
