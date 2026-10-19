import HandyCore
import HandyReplay
import Testing

private func clip(_ script: String, fps: Double = 30) throws -> Clip {
    Clip(hands: [try Clip.parseHand(script, chirality: .right)], fps: fps)
}

@Test func sameSeedGivesTheSameClip() throws {
    let noise = SynthNoise(jitterPixels: 3, dropout: 0.1, confidenceLoss: 0.1, seed: 42)
    let pinch = try clip("openPalm:500ms pinch:300ms")
    #expect(Synthesizer.render(pinch, noise: noise) == Synthesizer.render(pinch, noise: noise))
    #expect(
        Synthesizer.render(pinch, noise: noise)
            != Synthesizer.render(pinch, noise: SynthNoise(jitterPixels: 3, seed: 43)))
}

@Test func framesFollowTheScriptTimeline() throws {
    let frames = Synthesizer.render(try clip("openPalm:1s none:500ms", fps: 10))
    #expect(frames.count == 16)
    #expect(frames.prefix(10).allSatisfy { $0.hands.count == 1 })
    #expect(frames.suffix(5).allSatisfy { $0.hands.isEmpty })
}

@Test func wristMovesLinearlyAcrossAStep() throws {
    let frames = Synthesizer.render(try clip("openPalm:1s@0.2,0.5->1.2,0.5", fps: 10))
    #expect(frames[0].hands[0][.wrist]?.point == Point(x: 0.2, y: 0.5))
    let midway = try #require(frames[5].hands[0][.wrist]?.point.x)
    #expect(abs(midway - 0.7) < 1e-9)
}

@Test func jitterIsAboutTheRequestedPixels() throws {
    let still = try clip("openPalm:10s")
    let clean = Synthesizer.render(still)
    let noisy = Synthesizer.render(still, noise: SynthNoise(jitterPixels: 2, seed: 9))
    let offsets = zip(clean, noisy).compactMap { a, b -> Double? in
        guard let p = a.hands.first?[.indexTip]?.point, let q = b.hands.first?[.indexTip]?.point else { return nil }
        return (q.x - p.x) * 720
    }
    let rms = (offsets.map { $0 * $0 }.reduce(0, +) / Double(offsets.count)).squareRoot()
    #expect(abs(rms - 2) < 0.3)
}

@Test func dropoutAndConfidenceLossAreApplied() throws {
    let still = try clip("openPalm:10s")
    let dropped = Synthesizer.render(still, noise: SynthNoise(dropout: 0.5, seed: 3))
    let missing = dropped.filter { $0.hands.isEmpty }.count
    #expect((100...200).contains(missing))
    let dim = Synthesizer.render(still, noise: SynthNoise(confidenceLoss: 1, seed: 3))
    #expect(dim.allSatisfy { frame in frame.hands.allSatisfy { $0.joints.allSatisfy { $0?.confidence == 0.1 } } })
}

@Test func unknownPoseIsAParseError() {
    #expect(throws: ClipParseError.self) { try Clip.parseHand("wave:300ms", chirality: .right) }
    #expect(throws: ClipParseError.self) { try Clip.parseHand("pinch:3 minutes", chirality: .right) }
}

@Test func posesProduceTheFeaturesTheEngineReadsFrom() throws {
    func features(_ pose: PoseName) throws -> HandFeatures {
        var session = Session()
        for frame in Synthesizer.render(try clip("\(pose.rawValue):300ms")) { _ = session.process(frame) }
        return try #require(session.lastFeatures?.hands.first)
    }
    let open = try features(.openPalm)
    #expect([Finger.index, .middle, .ring, .little].allSatisfy(open.isExtended))
    #expect(try #require(open.pinchIndex) > 0.4)
    #expect(try #require(try features(.pinch).pinchIndex) < 0.25)
    #expect(try #require(try features(.pinchMiddle).pinchMiddle) < 0.25)
    let fist = try features(.fist)
    #expect(![Finger.index, .middle, .ring, .little].contains(where: fist.isExtended))
    let scroll = try features(.twoFingers)
    #expect(scroll.isExtended(.index) && scroll.isExtended(.middle) && !scroll.isExtended(.ring))
}

@Test func repeatedStepsStillPlayInOrder() throws {
    let frames = Synthesizer.render(try clip("relaxed:300ms fist:300ms relaxed:300ms", fps: 10))
    let reaches = frames.map { frame -> Double in
        var session = Session()
        _ = session.process(frame)
        return session.lastFeatures?.hands.first?.reach.index ?? .nan
    }
    #expect(reaches[1] > 0.3, "relaxed first")
    #expect(reaches[5] < 0, "then a fist")
    #expect(reaches[8] > 0.3, "then relaxed again")
}
