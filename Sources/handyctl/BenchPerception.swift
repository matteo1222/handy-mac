import ArgumentParser
import Foundation
import HandyCore
import HandyPerception
import HandyReplay

struct BenchPerception: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bench-perception",
        abstract: "Time hand-pose inference and filter+features against the per-frame budgets. Exits 1 over budget.",
        discussion: """
            Inference runs the Vision backend on rendered hand frames (no camera needed).
            Filter+features runs HandyCore's tracker and feature extractor on a two-hand synthetic clip.
            Budgets (docs/spec.md): inference p95 <= 10 ms, filter+features p95 <= 1 ms.
            """
    )

    @Option(help: "Inference iterations.")
    var iterations = 200

    @Option(help: "Seconds of synthetic two-hand footage for the filter+features timing.")
    var seconds = 60.0

    func run() throws {
        let clock = ContinuousClock()
        func milliseconds(_ duration: Duration) -> Double {
            Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
        }

        let provider = VisionHandPoseProvider()
        let frames = ["✋", "👍", "🤏", "🤙"].compactMap { SampleHandImage.pixelBuffer($0) }
        guard let warmup = frames.first else { throw ValidationError("could not render sample frames") }
        let modelLoad = try clock.measure { _ = try provider.hands(in: warmup) }
        var inference: [Double] = []
        var detected = 0
        for index in 0..<iterations {
            var hands: [HandPose] = []
            let elapsed = try clock.measure { hands = try provider.hands(in: frames[index % frames.count]) }
            inference.append(milliseconds(elapsed))
            detected += hands.isEmpty ? 0 : 1
        }

        let clip = Clip(hands: [
            try Clip.parseHand("openPalm:\(seconds)s@0.5,0.7->1.2,0.6", chirality: .right),
            try Clip.parseHand("fist:\(seconds)s@0.4,0.8", chirality: .left),
        ])
        let synthetic = Synthesizer.render(clip, noise: SynthNoise(jitterPixels: 2, seed: 1))
        var session = Session()
        var pipeline: [Double] = []
        for frame in synthetic {
            pipeline.append(milliseconds(clock.measure { _ = session.process(frame) }))
        }

        let report = PerceptionBenchReport(
            backend: provider.name,
            modelLoadMilliseconds: (milliseconds(modelLoad) * 10).rounded() / 10,
            inferenceMilliseconds: Summary(inference).rounded(),
            framesWithHand: detected,
            filterFeaturesMilliseconds: Summary(pipeline).rounded(10_000),
            budgets: .init(inferenceP95: 10, filterFeaturesP95: 1))
        try printJSON(report)
        if !report.withinBudget { throw ExitCode.failure }
    }
}

struct PerceptionBenchReport: Encodable {
    struct Budgets: Encodable {
        let inferenceP95: Double
        let filterFeaturesP95: Double
    }

    let backend: String
    let modelLoadMilliseconds: Double
    let inferenceMilliseconds: Summary
    let framesWithHand: Int
    let filterFeaturesMilliseconds: Summary
    let budgets: Budgets
    let withinBudget: Bool

    init(
        backend: String, modelLoadMilliseconds: Double, inferenceMilliseconds: Summary, framesWithHand: Int,
        filterFeaturesMilliseconds: Summary, budgets: Budgets
    ) {
        self.backend = backend
        self.modelLoadMilliseconds = modelLoadMilliseconds
        self.inferenceMilliseconds = inferenceMilliseconds
        self.framesWithHand = framesWithHand
        self.filterFeaturesMilliseconds = filterFeaturesMilliseconds
        self.budgets = budgets
        withinBudget =
            inferenceMilliseconds.p95 <= budgets.inferenceP95
            && filterFeaturesMilliseconds.p95 <= budgets.filterFeaturesP95
    }
}
