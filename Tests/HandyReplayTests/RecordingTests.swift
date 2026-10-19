import Foundation
import HandyCore
import HandyReplay
import Testing

/// What the app does while recording: append live frames one at a time, then replay the file.
@Test func recordedSessionReplaysToIdenticalFeatures() throws {
    let script = "relaxed:1s openPalm:1s@0.6,0.7->1.1,0.6 pinch:300ms twoFingers:1s"
    let clip = Clip(hands: [try Clip.parseHand(script, chirality: .right)], face: try Clip.parseFace("0:2s 50:2s"))
    let live = Synthesizer.render(
        clip, noise: SynthNoise(jitterPixels: 2.5, dropout: 0.05, confidenceLoss: 0.05, seed: 11))

    let url = FileManager.default.temporaryDirectory.appending(path: "handy-recording-\(UUID().uuidString).lmk")
    defer { try? FileManager.default.removeItem(at: url) }
    let writer = try LandmarkStreamWriter(url: url, header: .init(source: "vision"))
    var liveSession = Session()
    var liveFeatures: [FrameFeatures] = []
    for frame in live {
        try writer.append(frame)
        _ = liveSession.process(frame)
        liveFeatures.append(try #require(liveSession.lastFeatures))
    }
    try writer.close()

    let replayed = try LandmarkStream(contentsOf: url)
    var replaySession = Session()
    let replayFeatures = try replayed.frames.map { frame in
        _ = replaySession.process(frame)
        return try #require(replaySession.lastFeatures)
    }
    #expect(replayed.frames == live)
    #expect(replayFeatures == liveFeatures)
}
