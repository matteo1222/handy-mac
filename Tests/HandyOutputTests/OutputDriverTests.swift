import HandyCore
import HandyOutput
import Testing

@MainActor
private final class RefusingSink: EventSink {
    func post(_ action: OutputAction) -> Bool { false }
}

@MainActor
@Test func movesTheCursorFromWhereItIsAndKeepsItOnScreen() {
    let screen = Rect(x: 0, y: 0, width: 1000, height: 800)
    let environment = VirtualPointerEnvironment(screens: [screen])
    let sink = RecordingSink()
    let driver = OutputDriver(sink: sink, environment: environment)
    driver.handle(.moveCursor(dx: 100, dy: -50), at: 0)
    driver.handle(.moveCursor(dx: 1000, dy: 0), at: 0.5)
    #expect(sink.actions == [.moveCursor(to: Point(x: 600, y: 350)), .moveCursor(to: Point(x: 999, y: 350))])
    #expect(environment.cursor == Point(x: 999, y: 350))
}

@MainActor
@Test func refusedPostsAreReportedNotFatal() {
    let driver = OutputDriver(
        sink: RefusingSink(),
        environment: VirtualPointerEnvironment(screens: [Rect(x: 0, y: 0, width: 100, height: 100)]))
    driver.handle(.moveCursor(dx: 10, dy: 0), at: 0)
    #expect(driver.isBlocked)
    #expect(driver.failed == 1)
}
