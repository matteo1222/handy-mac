import Foundation
import HandyCore
import HandyReplay
import Testing

/// A whole tutorial run from one synthetic clip: engage, move, click, scroll, disengage.
private let walkthrough = """
    relaxed:500ms openPalm:600ms@0.9,0.75 openPalm:900ms->1.2,0.6 openPalm:500ms->0.7,0.8 openPalm:400ms \
    pinch:150ms openPalm:500ms twoFingers:300ms twoFingers:700ms->0.7,0.5 openPalm:500ms fist:500ms relaxed:300ms
    """

@Test func aSyntheticHandWalksTheWholeTutorial() throws {
    let clip = Clip(hands: [try Clip.parseHand(walkthrough, chirality: .right)])
    var session = Session()
    var tutorial = Tutorial(step: .engage)
    var recorder = CalibrationRecorder()
    var steps: [Tutorial.Step] = [tutorial.step]
    for frame in Synthesizer.render(clip, noise: SynthNoise(jitterPixels: 1, seed: 50)) {
        for timed in session.process(frame) { tutorial.handle(timed.event) }
        if let features = session.lastFeatures {
            recorder.observe(features, step: tutorial.step, mode: session.engine.mode)
        }
        if steps.last != tutorial.step { steps.append(tutorial.step) }
    }
    #expect(steps == [.engage, .move, .click, .scroll, .disengage, .done])

    let calibration = try #require(recorder.calibration())
    #expect(abs(calibration.handSize - 0.15) < 0.02)
    #expect(calibration.pinchPress < calibration.pinchRelease)
    #expect((0.15...0.35).contains(calibration.pinchPress))
    #expect(calibration.reachBox.width > 0.2 && calibration.reachBox.height > 0.1)
}

@Test func calibrationIsNumbersOnlyAndRoundTrips() throws {
    let calibration = Calibration(
        handSize: 0.14, pinchPress: 0.22, pinchRelease: 0.38, reachBox: Rect(x: 0.5, y: 0.5, width: 0.4, height: 0.2))
    let data = try JSONEncoder().encode(calibration)
    #expect(try JSONDecoder().decode(Calibration.self, from: data) == calibration)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(Set(object.keys) == ["version", "handSize", "pinchPress", "pinchRelease", "reachBox"])
    var settings = EngineSettings()
    calibration.apply(to: &settings)
    #expect(settings.click.press == 0.22 && settings.click.release == 0.38)
}

@Test func framingAdviceFollowsTheHand() throws {
    func advice(_ x: Double, _ y: Double, size: Double = 0.15, brightness: Double = 0.5) throws -> FramingAdvice {
        let clip = Clip(hands: [try Clip.parseHand("openPalm:100ms@\(x),\(y)~\(size)", chirality: .right)])
        var session = Session()
        for frame in Synthesizer.render(clip) { _ = session.process(frame) }
        let features = try #require(session.lastFeatures)
        return FramingAdvice.advise(features, brightness: brightness, aspect: 16.0 / 9)
    }
    #expect(try advice(0.9, 0.85) == .good)
    #expect(try advice(0.1, 0.85) == .moveRight)
    #expect(try advice(1.7, 0.85) == .moveLeft)
    #expect(try advice(0.9, 0.85, size: 0.02) == .comeCloser)
    #expect(try advice(0.9, 0.85, brightness: 0.05) == .moreLight)
    #expect(FramingAdvice.advise(FrameFeatures(t: 0, hands: []), brightness: 0.5, aspect: 16.0 / 9) == .raiseHand)
}

@Test func clickingTheTargetCompletesTheClickStep() {
    var tutorial = Tutorial(step: .move)
    tutorial.targetClicked()
    #expect(tutorial.step == .move, "only the click step listens for the target")
    tutorial = Tutorial(step: .click)
    tutorial.targetClicked()
    #expect(tutorial.step == .scroll)
}

@Test func gestureStepsCanBeSkippedButSetupStepsCannot() {
    var tutorial = Tutorial(step: .welcome)
    #expect(!tutorial.canSkip)
    tutorial.skip()
    #expect(tutorial.step == .welcome)
    for step in [Tutorial.Step.engage, .move, .click, .scroll, .disengage] {
        tutorial = Tutorial(step: step)
        tutorial.skip()
        #expect(tutorial.step == step.next)
    }
}
