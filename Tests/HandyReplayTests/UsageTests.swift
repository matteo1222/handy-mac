import HandyCore
import HandyReplay
import Testing

@Test func usageCountsEngagedTimeAndActionsFromAReplay() throws {
    let script = "openPalm:700ms pinch:150ms openPalm:2s fist:500ms relaxed:2s"
    let stream = Synthesizer.stream(Clip(hands: [try Clip.parseHand(script, chirality: .right)]))
    var session = Session()
    var meter = UsageMeter()
    for frame in stream.frames {
        for timed in session.process(frame) { meter.observe(timed.event) }
        meter.tick(at: frame.t)
    }
    let stats = meter.drain()
    #expect(stats.actions == ["click": 1])
    #expect(abs(stats.activeSeconds - 2.85) < 0.2, "engaged from 0.3 s until the fist at about 3.15 s")
    #expect(stats.oops == 0)
    #expect(stats.accidentalPerHour == 0)
}

@Test func accidentalRateIsOopsPerActiveHour() {
    var stats = UsageStats()
    stats.activeSeconds = 1800
    stats.oops = 1
    #expect(stats.accidentalPerHour == 2)
    var day = UsageStats()
    day.merge(stats)
    day.merge(stats)
    #expect(day.activeSeconds == 3600 && day.oops == 2 && day.accidentalPerHour == 2)
}
