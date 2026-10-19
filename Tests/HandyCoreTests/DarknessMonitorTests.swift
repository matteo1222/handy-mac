import HandyCore
import Testing

@Test func warnsAfterTwoSecondsOfDarknessAndClearsWithHysteresis() {
    var monitor = DarknessMonitor()
    for frame in 0..<59 { monitor.update(brightness: 0.05, at: Double(frame) / 30) }
    #expect(!monitor.isTooDark)
    monitor.update(brightness: 0.05, at: 2.0)
    #expect(monitor.isTooDark)
    monitor.update(brightness: 0.15, at: 2.1)
    #expect(monitor.isTooDark, "between the thresholds the warning holds")
    monitor.update(brightness: 0.25, at: 2.2)
    #expect(!monitor.isTooDark)
}

@Test func aBrightFrameResetsTheDwell() {
    var monitor = DarknessMonitor()
    for frame in 0..<50 { monitor.update(brightness: 0.05, at: Double(frame) / 30) }
    monitor.update(brightness: 0.3, at: 1.7)
    for frame in 52..<100 { monitor.update(brightness: 0.05, at: Double(frame) / 30) }
    #expect(!monitor.isTooDark)
}
