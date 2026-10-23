import HandyCore
import HandyPerception
import HandyReplay
import Testing

/// A drawn hand runs through the real tracker and the gesture engine: the end-to-end path a live
/// camera takes, with nobody in front of it.
func virtualCamera(_ script: String, backend: HandBackend) throws -> (VirtualCamera.Result, [TimedEvent]) {
    let track = try Clip.parseHand(script, chirality: .right)
    let seconds = track.steps.reduce(0) { $0 + $1.duration }
    let clip = Clip(hands: [track], face: try Clip.parseFace("0:\(Int((seconds * 1000).rounded(.up)))ms"))
    var frames: [VirtualCamera.Frame] = []
    Synthesizer.forEachScene(clip) { t, scene, face in
        guard let image = HandRenderer.image(scene) else { return }
        frames.append(
            VirtualCamera.Frame(
                t: t, image: image, truth: scene.map { $0.shape.pose(at: $0.placement) },
                handLength: scene.first?.placement.size ?? 1, face: face))
    }
    let result = try VirtualCamera(provider: backend.makeProvider()).track(frames)
    let events = Replayer.run(LandmarkStream(header: .init(source: "virtual-camera"), frames: result.frames))
    return (result, events)
}

extension PerceptionTests {
    /// Floors sit just under today's measurements for the drawn hand (MediaPipe lands within about a
    /// quarter of a hand length), so a regression shows.
    @Test func aDrawnOpenPalmIsFoundAndEngagesWithCoreML() throws {
        try expectDrawnPalmEngages(.coreml)
    }

    /// The drawn hand is a borderline input for Vision: byte-identical frames are found from the command
    /// line (GPU / Neural Engine) and often not in the test runner, where Vision may run on the CPU.
    @Test func aDrawnOpenPalmIsFoundAndEngagesWithVision() throws {
        withKnownIssue("Vision misses the drawn hand in the test process", isIntermittent: true) {
            try expectDrawnPalmEngages(.vision)
        }
    }

    func expectDrawnPalmEngages(_ backend: HandBackend) throws {
        let (result, events) = try virtualCamera("relaxed:400ms@1.0,0.85~0.2 openPalm:1500ms", backend: backend)
        #expect(result.handFoundRate > 0.7, "\(backend) found the hand in \(result.handFoundRate) of frames")
        let sorted = result.jointErrors.sorted()
        try #require(!sorted.isEmpty, "\(backend) matched no hand")
        #expect(
            sorted[sorted.count / 2] < 0.3, "\(backend) median joint error \(sorted[sorted.count / 2]) hand lengths")
        #expect(events.contains { $0.event == .modeChanged(to: .engaged) }, "\(backend) never engaged")
    }
}
