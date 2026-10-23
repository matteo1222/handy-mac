import HandyCore
import HandyPerception
import Testing

extension PerceptionTests {
    /// The classifier is trained on synthetic hands; rendered emoji give it real Vision landmarks.
    @Test(arguments: [("👍", PoseClass.thumbsUp), ("🤙", .shaka), ("✋", .none), ("🤏", .none)])
    func classifierReadsRealVisionLandmarks(_ emoji: String, _ expected: PoseClass) throws {
        let buffer = try #require(SampleHandImage.pixelBuffer(emoji, mirrored: true))
        let hands = try VisionHandPoseProvider().hands(in: buffer)
        var session = Session()
        _ = session.process(LandmarkFrame(t: 0, hands: hands))
        let hand = try #require(session.lastFeatures?.hands.first)
        let reading = try #require(PoseClassifier.standard.read(hand))
        #expect(reading.best.pose == expected, "\(emoji): \(reading.probabilities)")
    }
}
