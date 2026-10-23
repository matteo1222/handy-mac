import CoreVideo
import HandyCore
import Testing

@testable import HandyPerception

/// The Core ML backend finds the same hands as Vision, near the same places, and keeps them on the
/// tracked frames that skip the palm detector.
@Test(arguments: ["✋", "👍", "🤏", "🤙"])
func coreMLAgreesWithVision(_ emoji: String) throws {
    let buffer = try #require(SampleHandImage.pixelBuffer(emoji, mirrored: true))
    let vision = try #require(try VisionHandPoseProvider().hands(in: buffer).first)
    let coreML = try CoreMLHandPoseProvider()
    for frame in 0..<4 {
        let hand = try #require(try coreML.hands(in: buffer).first, "\(emoji): no hand on frame \(frame)")
        #expect(hand.joints.compactMap(\.self).count == 21)
        let distances = Joint.allCases.compactMap { joint -> Double? in
            guard let a = vision[joint]?.point, let b = hand[joint]?.point else { return nil }
            return a.distance(to: b)
        }
        let mean = distances.reduce(0, +) / Double(distances.count)
        // Frame heights; the backends disagree a little on where a cartoon hand's joints are.
        #expect(mean < 0.1, "\(emoji) frame \(frame): mean joint distance to Vision \(mean)")
    }
}

@Test func coreMLFindsNothingInAnEmptyFrame() throws {
    let buffer = try #require(SampleHandImage.pixelBuffer(" ", mirrored: true))
    #expect(try CoreMLHandPoseProvider().hands(in: buffer).isEmpty)
}

/// The periodic search for another hand finds the tracked one again and does not track it twice:
/// one hand costs one landmark run per frame, search frames included.
@Test func coreMLRedetectionKeepsOneTrackPerHand() throws {
    let buffer = try #require(SampleHandImage.pixelBuffer("✋", mirrored: true))
    let coreML = try CoreMLHandPoseProvider()
    for _ in 0..<25 { #expect(try coreML.hands(in: buffer).count == 1) }
    #expect(coreML.landmarkRuns == 25)
}

/// With background detection the hand found between frames is tracked from the next frame on.
@Test func coreMLBackgroundDetectionPicksTheHandUpNextFrame() async throws {
    let buffer = try #require(SampleHandImage.pixelBuffer("✋", mirrored: true))
    let coreML = try CoreMLHandPoseProvider(backgroundDetection: true)
    #expect(try coreML.hands(in: buffer).isEmpty)
    var hands: [HandPose] = []
    for _ in 0..<50 where hands.isEmpty {
        try await Task.sleep(for: .milliseconds(20))
        hands = try coreML.hands(in: buffer)
    }
    #expect(hands.count == 1)
}
