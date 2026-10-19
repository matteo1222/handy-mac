import HandyCore
import Testing

private func processedTimes(_ throttle: inout FrameThrottle, from start: Double, seconds: Double, hands: Bool)
    -> [Double]
{
    var processed: [Double] = []
    var t = start
    while t < start + seconds - 1e-9 {
        if throttle.shouldProcess(at: t) {
            processed.append(t)
            throttle.record(handsSeen: hands, at: t)
        }
        t += 1.0 / 30
    }
    return processed
}

@Test func processesEveryFrameWhileHandsAreSeen() {
    var throttle = FrameThrottle()
    let processed = processedTimes(&throttle, from: 0, seconds: 10, hands: true)
    #expect(processed.count == 300)
}

@Test func dropsToTenFramesPerSecondFiveSecondsAfterTheLastHand() {
    var throttle = FrameThrottle()
    let first = processedTimes(&throttle, from: 0, seconds: 5, hands: false)
    #expect(first.count == 150)
    let idle = processedTimes(&throttle, from: 5, seconds: 2, hands: false)
    #expect((19...21).contains(idle.count))
    #expect(throttle.isIdle(at: 7))
}

@Test func wakesUpAsSoonAsAHandReturns() {
    var throttle = FrameThrottle()
    _ = processedTimes(&throttle, from: 0, seconds: 6, hands: false)
    let first = throttle.shouldProcess(at: 6.2)
    throttle.record(handsSeen: true, at: 6.2)
    let next = throttle.shouldProcess(at: 6.2 + 1.0 / 30)
    #expect(first && next)
    #expect(!throttle.isIdle(at: 6.25))
}

@Test func faceRunsAtFiveFramesPerSecond() {
    var throttle = FrameThrottle()
    let ticks = (0..<30).map { Double($0) / 30 }.filter { throttle.shouldDetectFace(at: $0) }
    #expect(ticks.count == 5)
}
