import ArgumentParser
import Foundation
import HandyCore
import HandyReplay

struct Synth: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate a synthetic landmark clip (.lmk) from the pose library.",
        discussion: """
            With a preset (a pose name), the clip is: open palm 600 ms, the pose for --hold, open palm 400 ms.
            With --script, write the steps yourself: pose[:duration][@x,y][->x,y][~size], e.g.
              handyctl synth --script "relaxed:300ms openPalm:600ms@0.9,0.7 pinch:150ms openPalm:300ms" -o click.lmk
            Poses: none, \(PoseName.allCases.map(\.rawValue).joined(separator: ", ")).
            """
    )

    @Argument(help: "A pose name to use as a preset clip.")
    var preset: PoseName?

    @Option(help: "Script for the --hand hand (overrides the preset).")
    var script: String?

    @Option(help: "Script for the other hand, for two-hand clips.")
    var otherHand: String?

    @Option(help: "Face yaw script, e.g. \"0:1s 45:500ms\".")
    var face: String?

    @Option(help: "Chirality of the main hand.")
    var hand: Chirality = .right

    @Option(help: "Wrist position x,y in frame heights (preset only).")
    var at: String = "0.9,0.75"

    @Option(help: "How long the preset pose is held, e.g. 300ms.")
    var hold: String = "300ms"

    @Option(help: "Hand size in frame heights (wrist to middle MCP).")
    var size: Double = Synthesizer.defaultSize

    @Option(help: "Gaussian joint jitter, e.g. 2px.")
    var noise: String = "0px"

    @Option(help: "Probability a frame loses the hand.")
    var dropout: Double = 0

    @Option(help: "Probability a joint reports low confidence.")
    var confidenceLoss: Double = 0

    @Option(help: "Random seed; the same seed gives the same clip.")
    var seed: UInt64 = 1

    @Option(help: "Frames per second.")
    var fps: Double = 30

    @Option(name: .shortAndLong, help: "Output .lmk path.")
    var output: String

    func run() throws {
        let mainScript: String
        if let script {
            mainScript = script
        } else if let preset {
            mainScript = "openPalm:600ms@\(at)~\(size) \(preset.rawValue):\(hold) openPalm:400ms"
        } else {
            throw ValidationError("give a preset pose or --script")
        }
        var tracks = [try Clip.parseHand(mainScript, chirality: hand)]
        if let otherHand { tracks.append(try Clip.parseHand(otherHand, chirality: hand.other)) }
        let clip = Clip(hands: tracks, face: try face.map(Clip.parseFace) ?? [], fps: fps)
        guard noise.hasSuffix("px"), let jitter = Double(noise.dropLast(2)) else {
            throw ValidationError("--noise must look like 2px")
        }
        let synthNoise = SynthNoise(jitterPixels: jitter, dropout: dropout, confidenceLoss: confidenceLoss, seed: seed)
        let command = (["handyctl", "synth"] + CommandLine.arguments.dropFirst(2)).joined(separator: " ")
        let stream = Synthesizer.stream(clip, noise: synthNoise, meta: ["command": command])
        try stream.write(to: URL(filePath: output))
        try printJSON(SynthSummary(output: output, frames: stream.frames.count, duration: clip.duration))
    }
}

struct SynthSummary: Codable {
    let output: String
    let frames: Int
    let duration: Double
}

struct Replay: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Run a .lmk clip through HandyCore headless and diff the emitted events. Exits 1 on any diff."
    )

    @Argument(help: "The .lmk clip.")
    var clip: String

    @Option(help: "Expected events (.events.json) to diff against.")
    var expect: String?

    @Option(help: "Write the emitted events to this file (to bless a new expectation after review).")
    var writeExpected: String?

    @Flag(help: "Omit the full event list from the output.")
    var quiet = false

    func run() throws {
        let stream = try LandmarkStream(contentsOf: URL(filePath: clip))
        let clock = ContinuousClock()
        var events: [TimedEvent] = []
        let elapsed = clock.measure { events = Replayer.run(stream) }
        var diff: [EventDiff] = []
        if let expect {
            diff = Replayer.diff(expected: try Replayer.decode(Data(contentsOf: URL(filePath: expect))), actual: events)
        }
        if let writeExpected { try Replayer.encode(events).write(to: URL(filePath: writeExpected)) }
        let milliseconds = Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000
        try printJSON(
            ReplayReport(
                ok: diff.isEmpty, frames: stream.frames.count, eventCount: events.count,
                milliseconds: (milliseconds * 100).rounded() / 100, events: quiet ? nil : events, diff: diff))
        if !diff.isEmpty { throw ExitCode.failure }
    }
}

struct ReplayReport: Codable {
    let ok: Bool
    let frames: Int
    let eventCount: Int
    let milliseconds: Double
    let events: [TimedEvent]?
    let diff: [EventDiff]
}

extension PoseName: ExpressibleByArgument {}
extension Chirality: ExpressibleByArgument {}
