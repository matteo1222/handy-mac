import ArgumentParser
import Foundation
import HandyCore
import HandyPerception
import HandyReplay

struct Video: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Extract a landmark clip (.lmk) from a video file with the live camera's Vision pipeline.",
        discussion: """
            Frames are mirrored like the live camera (use --no-mirror for selfie footage that already is).
            Only landmark numbers are written; the video is not copied. Label segments with --label start:end:name.
            """)

    @Argument(help: "The video file (mov, mp4, m4v).")
    var input: String

    @Option(name: .shortAndLong, help: "Output .lmk path.")
    var output: String

    @Flag(inversion: .prefixedNo, help: "Mirror frames like the live camera.")
    var mirror = true

    @Option(help: "Hand-pose backend: vision or coreml.")
    var backend = "vision"

    @Option(help: "Frames per second to process.")
    var fps = 30.0

    @Option(parsing: .upToNextOption, help: "Labels as start:end:name, e.g. 0:4.5:none 4.5:6:click.")
    var label: [String] = []

    @Option(help: "Free-form source note stored in the header, e.g. a URL and licence.")
    var source: String?

    func run() async throws {
        let labels = try label.map { text -> LandmarkStream.Label in
            let parts = text.split(separator: ":")
            guard parts.count == 3, let start = Double(parts[0]), let end = Double(parts[1]) else {
                throw ValidationError("label \(text) must be start:end:name")
            }
            return LandmarkStream.Label(start: start, end: end, name: String(parts[2]))
        }
        guard let handBackend = HandBackend(rawValue: backend) else {
            throw ValidationError("backend must be vision or coreml")
        }
        let result = try await VideoLandmarks.process(
            URL(filePath: input),
            options: VideoLandmarks.Options(
                mirror: mirror, fps: fps,
                backend: handBackend))
        var meta = ["aspect": String(result.aspect), "video": URL(filePath: input).lastPathComponent]
        meta["source"] = source
        let stream = LandmarkStream(header: .init(source: "video", labels: labels, meta: meta), frames: result.frames)
        try stream.write(to: URL(filePath: output))
        try printJSON(
            VideoSummary(
                output: output, frames: result.frames.count,
                framesWithHands: result.frames.filter { !$0.hands.isEmpty }.count,
                duration: result.frames.last?.t ?? 0,
                inferenceMilliseconds: Summary(result.inferenceMilliseconds).rounded()))
    }
}

struct VideoSummary: Codable {
    let output: String
    let frames: Int
    let framesWithHands: Int
    let duration: Double
    let inferenceMilliseconds: Summary
}
