import HandyCore
import HandyReplay
import Testing

@Test func armingProgressFillsOverTheHold() throws {
    let clip = Clip(hands: [try Clip.parseHand("openPalm:1s", chirality: .right)])
    var session = Session()
    var progress: [Double] = []
    for frame in Synthesizer.render(clip) {
        _ = session.process(frame)
        if let value = session.engine.status(at: frame.t).progress { progress.append(value) }
    }
    #expect(progress.first == 0)
    #expect(progress == progress.sorted())
    #expect(try #require(progress.last) > 0.85)
    #expect(session.engine.mode == .engaged)
    #expect(session.engine.status(at: 1).progress == nil)
}

@Test func leftHandDoesNotEngageWhenTheRightHandPoints() throws {
    let clip = Clip(hands: [try Clip.parseHand("openPalm:1s", chirality: .left)])
    let events = Replayer.run(Synthesizer.stream(clip))
    #expect(events.isEmpty)
}

@Test func stopFromEngagedTurnsEverythingOff() throws {
    let clip = Clip(hands: [try Clip.parseHand("openPalm:1s", chirality: .right)])
    var session = Session()
    for frame in Synthesizer.render(clip) { _ = session.process(frame) }
    #expect(session.engine.mode == .engaged)
    #expect(session.send(.stop, at: 1).map(\.event) == [.modeChanged(to: .off)])
}
