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

@Test func clickMeterRisesAsThePinchClosesAndFillsAtThePress() throws {
    func meter(_ pose: PoseName) throws -> Double {
        var session = Session()
        for frame in Synthesizer.render(Clip(hands: [try Clip.parseHand("\(pose.rawValue):300ms", chirality: .right)]))
        {
            _ = session.process(frame)
        }
        let hand = try #require(session.lastFeatures?.hands.first)
        return SensitivityMeter.read(
            .click, hand: hand, status: session.engine.status(at: 0.3), settings: session.engine.settings)
    }
    let open = try meter(.openPalm)
    let near = try meter(.nearPinch)
    let pinched = try meter(.pinch)
    #expect(open == 0)
    #expect(near > 0.3 && near < 1)
    #expect(pinched == 1)
}

@Test func otherHandOpenPalmForTwoSecondsShowsTheCheatSheetAndLoweringItHides() throws {
    let clip = Clip(hands: [
        try Clip.parseHand("relaxed:3s", chirality: .right),
        try Clip.parseHand("openPalm:2500ms@0.5,0.75 none:1s", chirality: .left),
    ])
    let events = Replayer.run(Synthesizer.stream(clip)).map(\.event)
    #expect(events.filter { $0 == .cheatSheet(shown: true) }.count == 1)
    #expect(events.filter { $0 == .cheatSheet(shown: false) }.count == 1)
    #expect(!events.contains(.modeChanged(to: .arming)), "the other hand never engages")
}
