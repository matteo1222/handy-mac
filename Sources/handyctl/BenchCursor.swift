import ArgumentParser
import HandyCore
import HandyReplay

struct BenchCursor: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bench-cursor",
        abstract: "Measure cursor jitter (points RMS) while an engaged hand holds still, at several noise levels.",
        discussion: "Synthesises a still open palm with Gaussian joint noise and replays it headlessly.")

    @Option(help: "Seconds of still hand per noise level.")
    var seconds = 6.0

    @Option(parsing: .upToNextOption, help: "Joint noise levels in pixels of a 720p frame.")
    var noise: [Double] = [0, 1, 2, 4]

    @Option(help: "Hand size in frame heights (0.15 is about 0.6 m from the camera).")
    var size = 0.15

    func run() throws {
        let clip = Clip(hands: [try Clip.parseHand("openPalm:\(seconds)s~\(size)", chirality: .right)])
        let rows = noise.map { pixels in
            let stream = Synthesizer.stream(clip, noise: SynthNoise(jitterPixels: pixels, seed: 21))
            let jitter = CursorTrace.jitter(CursorTrace.run(stream))
            return CursorJitterRow(noisePixels: pixels, jitterPoints: (jitter * 1000).rounded() / 1000)
        }
        try printJSON(rows)
    }
}

struct CursorJitterRow: Codable {
    let noisePixels: Double
    let jitterPoints: Double
}
