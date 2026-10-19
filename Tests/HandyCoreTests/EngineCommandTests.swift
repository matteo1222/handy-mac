import HandyCore
import Testing

@Test func toggleSwitchesBetweenOffAndWatching() {
    var engine = Engine()
    #expect(engine.handle(.command(.toggle)) == [.modeChanged(to: .watching)])
    #expect(engine.handle(.command(.toggle)) == [.modeChanged(to: .off)])
}

@Test func stopReturnsToOffFromEveryMode() {
    for mode in Engine.Mode.allCases {
        var engine = Engine(mode: mode)
        _ = engine.handle(.command(.stop))
        #expect(engine.mode == .off)
    }
}

@Test func repeatedStopEmitsNothing() {
    var engine = Engine()
    #expect(engine.handle(.command(.stop)).isEmpty)
}
