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
    private var dragging: MouseButton?
    private var scrollRemainder = Point.zero
    private var coasting = false
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
            move(by: Point(x: dx, y: dy), at: t) { .moveCursor(to: $0) }
        case .click(let button, let count):
            let at = environment.cursor
            if post(.mouseDown(button: button, at: at, clickCount: count)) {
                post(.mouseUp(button: button, at: at, clickCount: count))
            }
        case .dragBegan(let button):
            dragging = button
            post(.mouseDown(button: button, at: environment.cursor, clickCount: 1))
        case .dragMoved(let dx, let dy):
            let button = dragging ?? .left
            move(by: Point(x: dx, y: dy), at: t) { .mouseDragged(button: button, to: $0) }
        case .dragEnded(let button):
            dragging = nil
            post(.mouseUp(button: button, at: environment.cursor, clickCount: 1))
        case .scroll(let dx, let dy, let phase):
            scroll(dx: dx, dy: dy, phase: phase)
        case .oneShot, .flick, .swipe, .zoom:
            break  // Gestures become actions through the ActionRouter, then `perform`.
        }
    }

    public func perform(_ action: Action) {
        switch action {
        case .key(let chord): post(.keyStroke(chord))
        case .previousSpace, .nextSpace, .missionControl:
            if let chord = SymbolicHotKeys.chord(for: action) { post(.keyStroke(chord)) }
        case .toggleDictation:
            switch dictation() {
            case .doubleTap(let modifier): post(.modifierDoubleTap(modifier))
            case .chord(let chord): post(.keyStroke(chord))
            case .globe: post(.modifierDoubleTap(nil))
            case nil: dictationUnavailable = true
            }
        }
    }

    /// Set when Dictation was asked for but is off or has no shortcut; the app guides the user.
    public var dictationUnavailable = false
    /// Where the Dictation shortcut comes from; replaceable for tests.
    public var dictation: () -> DictationShortcut? = { DictationShortcut.current() }

    /// Wheel events carry whole pixels; the fractional remainder carries into the next event.
    private func scroll(dx: Double, dy: Double, phase: ScrollPhase) {
        scrollRemainder += Point(x: dx, y: dy)
        let whole = Point(x: scrollRemainder.x.rounded(.towardZero), y: scrollRemainder.y.rounded(.towardZero))
        scrollRemainder -= whole
        let momentumStart = phase == .momentum && !coasting
        coasting = phase == .momentum
        if phase == .began || phase == .momentumEnded { scrollRemainder = .zero }
        post(.scroll(dx: Int(whole.x), dy: Int(whole.y), phase: phase, momentumStart: momentumStart))
    }

    private func move(by delta: Point, at t: Double, action: (Point) -> OutputAction) {
        let from = environment.cursor
        let screen = environment.screens.first { $0.contains(from) } ?? environment.screens.first
        guard let screen else { return }
        let to = edge.apply(from: from, delta: delta, screen: screen, at: t)
        guard to != from else { return }
        if post(action(to)) { environment.cursorMoved(to: to) }
    }

    @discardableResult
    private func post(_ action: OutputAction) -> Bool {
        isBlocked = !sink.post(action)
        if isBlocked { failed += 1 } else { posted += 1 }
        return !isBlocked
    }
}
