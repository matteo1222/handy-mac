import Foundation
import HandyCore
import HandyReplay
import Testing

@Test func replayIsDeterministicAndFast() throws {
    let script = "relaxed:2s openPalm:2s pinch:1s openPalm:1s fist:2s twoFingers:2s"
    let clip = Clip(hands: [try Clip.parseHand(script, chirality: .right)])
    let stream = Synthesizer.stream(clip, noise: SynthNoise(jitterPixels: 2, dropout: 0.05, seed: 5))
    let clock = ContinuousClock()
    var first: [TimedEvent] = []
    let elapsed = clock.measure { first = Replayer.run(stream) }
    #expect(Replayer.run(stream) == first)
    #expect(elapsed < .seconds(1))
}

@Test func diffReportsMissingExtraAndChangedEvents() {
    let watching = TimedEvent(t: 0, event: .modeChanged(to: .watching))
    let off = TimedEvent(t: 1, event: .modeChanged(to: .off))
    #expect(Replayer.diff(expected: [watching, off], actual: [watching, off]).isEmpty)
    #expect(
        Replayer.diff(expected: [watching], actual: [watching, off]) == [
            EventDiff(index: 1, expected: nil, actual: off)
        ])
    #expect(
        Replayer.diff(expected: [off], actual: [watching])
            == [EventDiff(index: 0, expected: off, actual: watching)])
}

@Test func diffToleratesFloatingPointNoiseOnly() {
    let a = TimedEvent(t: 0.1, event: .modeChanged(to: .off))
    #expect(Replayer.diff(expected: [a], actual: [TimedEvent(t: 0.1 + 1e-9, event: .modeChanged(to: .off))]).isEmpty)
    #expect(Replayer.diff(expected: [a], actual: [TimedEvent(t: 0.2, event: .modeChanged(to: .off))]).count == 1)
}

/// Every gesture needs `Fixtures/gestures/<name>.lmk` and `<name>.events.json`, and the replay must match.
@Test func everyGestureHasAPassingReplayFixture() throws {
    #expect(try fixtureProblems(for: Gesture.self) == [])
}

func fixtureProblems<G: CaseIterable>(for _: G.Type) throws -> [String] {
    var problems: [String] = []
    for gesture in G.allCases {
        let name = String(describing: gesture)
        let base = "Fixtures/gestures/\(name)"
        guard let clip = Bundle.module.url(forResource: base, withExtension: "lmk") else {
            problems.append("missing replay fixture \(base).lmk")
            continue
        }
        guard let expected = Bundle.module.url(forResource: base, withExtension: "events.json") else {
            problems.append("missing expected events \(base).events.json")
            continue
        }
        let actual = Replayer.run(try LandmarkStream(contentsOf: clip))
        let diff = Replayer.diff(expected: try Replayer.decode(Data(contentsOf: expected)), actual: actual)
        if !diff.isEmpty { problems.append("replay of \(name) differs at events \(diff.map(\.index))") }
    }
    return problems
}

private enum ProbeGesture: CaseIterable { case uncovered }

@Test func coverageCheckFailsForAGestureWithoutAFixture() throws {
    #expect(try fixtureProblems(for: ProbeGesture.self) == ["missing replay fixture Fixtures/gestures/uncovered.lmk"])
}

/// Negative and edge-case clips must replay to exactly their expected events too.
@Test func everyScenarioFixtureReplaysAsExpected() throws {
    let folder = try fixture("scenarios")
    let clips = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "lmk" }
    #expect(!clips.isEmpty)
    for clip in clips {
        let expected = clip.deletingPathExtension().appendingPathExtension("events.json")
        let actual = Replayer.run(try LandmarkStream(contentsOf: clip))
        let diff = Replayer.diff(expected: try Replayer.decode(Data(contentsOf: expected)), actual: actual)
        #expect(diff.isEmpty, "\(clip.lastPathComponent) differs: \(diff)")
    }
}
