import HandyCore
import Testing

@Test func gainRisesSmoothlyFromSlowToFast() {
    let settings = PointerSettings()
    #expect(settings.gain(atSpeed: 0) == settings.slowGain)
    #expect(settings.gain(atSpeed: 10) == settings.fastGain)
    let speeds = stride(from: 0.0, through: 1.0, by: 0.05).map(settings.gain(atSpeed:))
    #expect(speeds == speeds.sorted())
}

@Test func fasterPalmCoversMoreScreenForTheSameDistance() {
    func travel(over seconds: Double) -> Double {
        var tracker = PointerTracker(settings: PointerSettings())
        tracker.reanchor(at: Point(x: 0.5, y: 0.5), t: 0)
        var total = 0.0
        let steps = Int(seconds * 30)
        for step in 1...steps + 30 {
            let progress = min(Double(step) / Double(steps), 1)
            let point = Point(x: 0.5 + 0.2 * progress, y: 0.5)
            total += tracker.delta(for: point, at: Double(step) / 30)?.x ?? 0
        }
        return total
    }
    #expect(travel(over: 0.2) > travel(over: 2) * 2)
}

@Test func stillPalmProducesNoMotion() {
    var tracker = PointerTracker(settings: PointerSettings())
    tracker.reanchor(at: Point(x: 0.5, y: 0.5), t: 0)
    let deltas = (1...60).compactMap { tracker.delta(for: Point(x: 0.5, y: 0.5), at: Double($0) / 30) }
    #expect(deltas.isEmpty)
}

@Test func edgeStickHoldsTheCursorOnArrivalThenReleases() {
    var edge = EdgeStick()
    let screen = Rect(x: 0, y: 0, width: 1000, height: 800)
    var position = Point(x: 500, y: 60)
    position = edge.apply(from: position, delta: Point(x: 0, y: -50), screen: screen, at: 0)
    #expect(position == Point(x: 500, y: 10))
    let held = edge.apply(from: position, delta: Point(x: 0, y: 40), screen: screen, at: 0.1)
    #expect(held == position)
    let released = edge.apply(from: position, delta: Point(x: 0, y: 40), screen: screen, at: 0.2)
    #expect(released == Point(x: 500, y: 50))
}

@Test func cursorNeverLeavesTheScreen() {
    var edge = EdgeStick()
    let screen = Rect(x: 0, y: 0, width: 1000, height: 800)
    let position = edge.apply(from: Point(x: 990, y: 400), delta: Point(x: 500, y: 0), screen: screen, at: 0)
    #expect(position == Point(x: 999, y: 400))
}
