import HandyCore
import Testing

private struct Driver {
    var scroll = ScrollRecognizer(settings: ScrollSettings())
    var t = 0.0

    mutating func frame(pose: Bool, motion: Point = .zero, cursorMoved: Bool = false) -> [Engine.Event] {
        t += 1.0 / 30
        return scroll.update(isScrollPose: pose, motion: motion, cursorMoved: cursorMoved, at: t)
    }
}

@Test func poseMustHoldBeforeScrollingBegins() {
    var driver = Driver()
    let early = (0..<5).flatMap { _ in driver.frame(pose: true) }
    #expect(early.isEmpty)
    #expect(driver.frame(pose: true) == [.scroll(dx: 0, dy: 0, phase: .began)])
    #expect(driver.scroll.isScrolling)
}

@Test func contentFollowsTheHandAtAFixedGain() {
    var driver = Driver()
    for _ in 0..<6 { _ = driver.frame(pose: true) }
    #expect(driver.frame(pose: true, motion: Point(x: 0, y: -0.01)) == [.scroll(dx: 0, dy: -30, phase: .changed)])
}

@Test func releaseCoastsWithMomentumThatDecaysEachFrame() throws {
    var driver = Driver()
    for _ in 0..<6 { _ = driver.frame(pose: true) }
    for _ in 0..<6 { _ = driver.frame(pose: true, motion: Point(x: 0, y: 0.02)) }
    let lost = (0..<6).flatMap { _ in driver.frame(pose: false) }
    #expect(lost.first == .scroll(dx: 0, dy: 0, phase: .ended))
    guard case .scroll(_, let first, .momentum) = try #require(lost.last) else {
        Issue.record("expected momentum after release")
        return
    }
    guard case .scroll(_, let second, .momentum) = try #require(driver.frame(pose: false).first) else {
        Issue.record("expected momentum to continue")
        return
    }
    #expect(abs(second / first - 0.92) < 1e-9)
}

@Test func pointingAgainStopsMomentumOnlyAfterTheGrace() {
    var driver = Driver()
    for _ in 0..<6 { _ = driver.frame(pose: true) }
    for _ in 0..<6 { _ = driver.frame(pose: true, motion: Point(x: 0, y: 0.02)) }
    for _ in 0..<6 { _ = driver.frame(pose: false) }
    #expect(driver.frame(pose: false, cursorMoved: true).first?.isMomentumEnded == false)
    for _ in 0..<8 { _ = driver.frame(pose: false) }
    #expect(driver.frame(pose: false, cursorMoved: true) == [.scroll(dx: 0, dy: 0, phase: .momentumEnded)])
}

extension Engine.Event {
    fileprivate var isMomentumEnded: Bool {
        if case .scroll(_, _, .momentumEnded) = self { return true }
        return false
    }
}
