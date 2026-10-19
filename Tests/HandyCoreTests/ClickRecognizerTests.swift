import HandyCore
import Testing

/// Drives the recognizer one 30 fps frame at a time.
private struct Driver {
    var clicks = ClickRecognizer(settings: ClickSettings())
    var t = 0.0
    var palm = Point.zero

    mutating func frame(index: Double? = 0.8, middle: Double? = 0.9, move: Point = .zero) -> [Engine.Event] {
        t += 1.0 / 30
        palm += move
        return clicks.update(
            pinchIndex: index, pinchMiddle: middle, delta: move == .zero ? nil : move, palm: palm, at: t)
    }
}

@Test func pressThenQuickReleaseIsOneClick() {
    var driver = Driver()
    #expect(driver.frame(index: 0.2).isEmpty)
    #expect(driver.frame(index: 0.3).isEmpty, "inside the hysteresis band the press holds")
    #expect(driver.frame(index: 0.5) == [.click(button: .left, count: 1)])
}

@Test func cursorIsFrozenFromPinchOnset() {
    var driver = Driver()
    _ = driver.frame(index: 0.2)
    let during = driver.frame(index: 0.2, move: Point(x: 3, y: 0)) + driver.frame(index: 0.2, move: Point(x: 3, y: 0))
    #expect(during.isEmpty)
    #expect(driver.frame(index: 0.5) == [.click(button: .left, count: 1)])
}

@Test func movingPastEightPointsStartsADragCarryingTheHeldMotion() {
    var driver = Driver()
    _ = driver.frame(index: 0.2)
    _ = driver.frame(index: 0.2, move: Point(x: 5, y: 0))
    let events = driver.frame(index: 0.2, move: Point(x: 5, y: 0))
    #expect(events == [.dragBegan(button: .left), .dragMoved(dx: 10, dy: 0)])
    #expect(driver.frame(index: 0.2, move: Point(x: 2, y: 1)) == [.dragMoved(dx: 2, dy: 1)])
    #expect(driver.frame(index: 0.5) == [.dragEnded(button: .left)])
}

@Test func holdingPastTheClickWindowStartsADrag() {
    var driver = Driver()
    _ = driver.frame(index: 0.2)
    let events = (0..<9).flatMap { _ in driver.frame(index: 0.2) }
    #expect(events == [.dragBegan(button: .left)])
}

@Test func secondQuickPressIsADoubleClickAndASlowOneIsNot() {
    var quick = Driver()
    _ = quick.frame(index: 0.2)
    _ = quick.frame(index: 0.5)
    _ = quick.frame(index: 0.5)
    _ = quick.frame(index: 0.2)
    #expect(quick.frame(index: 0.5) == [.click(button: .left, count: 2)])

    var slow = Driver()
    _ = slow.frame(index: 0.2)
    _ = slow.frame(index: 0.5)
    for _ in 0..<15 { _ = slow.frame(index: 0.5) }
    _ = slow.frame(index: 0.2)
    #expect(slow.frame(index: 0.5) == [.click(button: .left, count: 1)])
}

@Test func middlePinchIsARightClick() {
    var driver = Driver()
    _ = driver.frame(index: 0.6, middle: 0.2)
    #expect(driver.frame(index: 0.6, middle: 0.5) == [.click(button: .right, count: 1)])
}

@Test func missingTipsNeverPressOrRelease() {
    var driver = Driver()
    #expect(driver.frame(index: nil, middle: nil).isEmpty)
    _ = driver.frame(index: 0.2)
    #expect(driver.frame(index: nil).isEmpty, "an unknown reading holds the press")
    #expect(driver.frame(index: 0.5) == [.click(button: .left, count: 1)])
}

@Test func motionRightAfterAClickWaitsForTheDoubleClickWindow() {
    var driver = Driver()
    _ = driver.frame(index: 0.2)
    _ = driver.frame(index: 0.5)
    #expect(driver.frame(move: Point(x: 4, y: 0)).isEmpty)
    #expect(driver.frame(move: Point(x: 10, y: 0)) == [.moveCursor(dx: 14, dy: 0)])
}

@Test func ringClosenessTracksThePinch() {
    let clicks = ClickRecognizer(settings: ClickSettings())
    #expect(clicks.closeness(pinchIndex: 1.0, pinchMiddle: nil) == 0)
    #expect(clicks.closeness(pinchIndex: 0.25, pinchMiddle: nil) == 1)
    let half = clicks.closeness(pinchIndex: 0.425, pinchMiddle: 1.0) ?? -1
    #expect(abs(half - 0.5) < 1e-9)
    #expect(clicks.closeness(pinchIndex: nil, pinchMiddle: nil) == nil)
}

@Test func thumbOnACurledFingerIsNotAPinch() {
    var clicks = ClickRecognizer(settings: ClickSettings())
    let curledMiddle = FingerValues(thumb: 0.3, index: 0.9, middle: -0.3, ring: -0.3, little: -0.3)
    for frame in 1...10 {
        let events = clicks.update(
            pinchIndex: 1.3, pinchMiddle: 0.1, delta: nil, palm: .zero, at: Double(frame) / 30, reach: curledMiddle)
        #expect(events.isEmpty)
    }
    #expect(clicks.phase == .idle)
}
