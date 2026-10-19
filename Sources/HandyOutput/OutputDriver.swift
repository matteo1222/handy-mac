import AppKit
import HandyCore

/// Where the cursor is and which screens exist.
@MainActor
public protocol PointerEnvironment: AnyObject {
    var cursor: Point { get }
    var screens: [Rect] { get }
    /// Called after the sink accepted a move, for environments that track the cursor themselves.
    func cursorMoved(to point: Point)
}

/// The real displays and the real cursor.
@MainActor
public final class LivePointerEnvironment: PointerEnvironment {
    public init() {}

    public var cursor: Point {
        let location = CGEvent(source: nil)?.location ?? .zero
        return Point(x: location.x, y: location.y)
    }

    /// The posted event moved the real cursor; the next read sees it.
    public func cursorMoved(to point: Point) {}

    public var screens: [Rect] { Self.activeDisplays() }

    /// Every screen in Quartz coordinates (top-left origin of the primary display).
    /// NSScreen, not CGGetActiveDisplayList, which reports no displays to some processes.
    public static func activeDisplays() -> [Rect] {
        guard let primary = NSScreen.screens.first?.frame else { return [] }
        return NSScreen.screens.map { screen in
            let frame = screen.frame
            return Rect(x: frame.minX, y: primary.maxY - frame.maxY, width: frame.width, height: frame.height)
        }
    }
}

/// A cursor that only exists in memory, starting at the centre of the main display, for recordings.
@MainActor
public final class VirtualPointerEnvironment: PointerEnvironment {
    public private(set) var cursor: Point
    public let screens: [Rect]

    public func cursorMoved(to point: Point) {
        cursor = point
    }

    public init(screens: [Rect] = LivePointerEnvironment.activeDisplays()) {
        let main = screens.first ?? Rect(x: 0, y: 0, width: 1512, height: 982)
        self.screens = screens.isEmpty ? [main] : screens
        cursor = Point(x: main.x + main.width / 2, y: main.y + main.height / 2)
    }
}

/// Turns engine events into OS actions: applies edge stick, tracks the cursor, posts to the sink.
@MainActor
public final class OutputDriver {
    public let sink: any EventSink
    public let environment: any PointerEnvironment
    private var edge = EdgeStick()
    /// True after a post failed for lack of Accessibility permission; cleared by the next success.
    public private(set) var isBlocked = false
    public private(set) var posted = 0
    public private(set) var failed = 0

    public init(sink: any EventSink, environment: any PointerEnvironment) {
        self.sink = sink
        self.environment = environment
    }

    public func handle(_ event: Engine.Event, at t: Double) {
        switch event {
        case .modeChanged:
            edge = EdgeStick()
        case .moveCursor(let dx, let dy):
            let from = environment.cursor
            let screen = environment.screens.first { $0.contains(from) } ?? environment.screens.first
            guard let screen else { return }
            let to = edge.apply(from: from, delta: Point(x: dx, y: dy), screen: screen, at: t)
            guard to != from else { return }
            if post(.moveCursor(to: to)) { environment.cursorMoved(to: to) }
        }
    }

    @discardableResult
    private func post(_ action: OutputAction) -> Bool {
        isBlocked = !sink.post(action)
        if isBlocked { failed += 1 } else { posted += 1 }
        return !isBlocked
    }
}
