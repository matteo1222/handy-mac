import HandyCore
import HandyPerception
import Testing

extension PerceptionTests {
    @Test func visionFindsAllJointsOfARenderedOpenHand() throws {
        let buffer = try #require(SampleHandImage.pixelBuffer("✋"))
        let hands = try VisionHandPoseProvider().hands(in: buffer)
        let hand = try #require(hands.first)
        #expect(hands.count == 1)
        #expect(hand.joints.compactMap { $0 }.filter { $0.confidence >= 0.3 }.count == 21)
        let wrist = try #require(hand[.wrist]?.point)
        let middleTip = try #require(hand[.middleTip]?.point)
        #expect(middleTip.y < wrist.y, "fingers point up in top-left-origin coordinates")
        #expect((0...16.0 / 9).contains(wrist.x) && (0...1).contains(wrist.y))
    }

    @Test func visionOutputFlowsIntoOpenPalmFeatures() throws {
        let buffer = try #require(SampleHandImage.pixelBuffer("✋"))
        let provider = VisionHandPoseProvider()
        var session = Session()
        for frame in 0..<5 {
            _ = session.process(LandmarkFrame(t: Double(frame) / 30, hands: try provider.hands(in: buffer)))
        }
        let hand = try #require(session.lastFeatures?.hands.first)
        #expect([Finger.index, .middle, .ring, .little].allSatisfy(hand.isExtended))
        #expect(hand.palmFacing > 0.4)
    }

    @Test func geometryFlipsYAndScalesXByAspect() {
        let geometry = ImageGeometry(width: 1280, height: 720)
        let point = geometry.point(normalizedX: 0.5, normalizedY: 0.25)
        #expect(abs(point.x - 16.0 / 18) < 1e-12)
        #expect(point.y == 0.75)
    }
}
