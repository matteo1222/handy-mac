import HandyCore
import HandyReplay
import Testing

@Test func sessionPhasesFollowThePromptsAndLabelMatchThem() {
    let prompts = [
        CorpusPrompt(label: "click", instruction: "Pinch", seconds: 4),
        CorpusPrompt(label: "none", instruction: "Type", seconds: 10),
    ]
    var session = CorpusSession(prompts: prompts, gap: 2)
    #expect(session.phase(at: 100) == .reading(next: 0, remaining: 2))
    #expect(session.phase(at: 103) == .doing(index: 0, remaining: 3))
    #expect(session.phase(at: 107) == .reading(next: 1, remaining: 1))
    #expect(session.phase(at: 110) == .doing(index: 1, remaining: 8))
    #expect(session.phase(at: 118) == .finished)
    #expect(
        session.labels == [
            LandmarkStream.Label(start: 2, end: 6, name: "click"),
            LandmarkStream.Label(start: 8, end: 18, name: "none"),
        ])
    #expect(session.totalSeconds == 18)
}

@Test func theStandardProtocolLabelsEveryGestureAndEnoughNoGesture() {
    let labels = Set(CorpusPrompt.standard.map(\.label))
    for gesture in Gesture.allCases {
        #expect(labels.contains(gesture.rawValue), "\(gesture) is never prompted")
    }
    let noGesture = CorpusPrompt.standard.filter { $0.label == "none" }.reduce(0) { $0 + $1.seconds }
    #expect(noGesture * 12 * 3 >= 7200, "three participants over a 4 × 3 grid give 2 h of no-gesture footage")
}

@Test func labelledCorpusClipsAreScoredForRecall() throws {
    let clip = Clip(hands: [try Clip.parseHand("relaxed:2s openPalm:700ms pinch:150ms openPalm:1s", chirality: .right)])
    let stream = LandmarkStream(
        header: .init(
            source: "corpus", labels: [.init(start: 0, end: 2, name: "none"), .init(start: 2, end: 3.9, name: "click")]),
        frames: Synthesizer.render(clip))
    var accumulator = Bench.Accumulator()
    accumulator.run(frames: { stream.frames.forEach($0) }, labels: stream.header.labels)
    #expect(accumulator.recallTotals["click"] == 1)
    #expect(accumulator.recallHits["click"] == 1)
    #expect(accumulator.falseActions.isEmpty)
}
