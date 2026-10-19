import CoreGraphics
import HandyCore

/// Where output actions go: the real input stream, or a recording for agents and tests.
@MainActor
public protocol EventSink: AnyObject {
    /// Returns false when the action could not be delivered (for example, no Accessibility permission).
    func post(_ action: OutputAction) -> Bool
}

/// Posts real input events with CGEvent. The only place in Handy that touches the input stream.
@MainActor
public final class CGEventSink: EventSink {
    private let source = CGEventSource(stateID: .hidSystemState)

    public init() {}

    public func post(_ action: OutputAction) -> Bool {
        guard AccessibilityPermission.isGranted else { return false }
        if case .keyStroke(let chord) = action { return postKey(chord) }
        let event: CGEvent? =
            if case .scroll(let dx, let dy, let phase, let momentumStart) = action {
                scrollEvent(dx: dx, dy: dy, phase: phase, momentumStart: momentumStart)
            } else {
                mouseEvent(for: action)
            }
        guard let event else { return false }
        event.post(tap: .cghidEventTap)
        return true
    }

    private func postKey(_ chord: KeyChord) -> Bool {
        guard let code = KeyboardLayout.keyCode(for: chord.key) else { return false }
        var flags = CGEventFlags()
        if chord.modifiers.contains(.command) { flags.insert(.maskCommand) }
        if chord.modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if chord.modifiers.contains(.control) { flags.insert(.maskControl) }
        if chord.modifiers.contains(.shift) { flags.insert(.maskShift) }
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else {
                return false
            }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
        return true
    }

    /// A continuous (trackpad-like) pixel scroll event with scroll and momentum phases set.
    private func scrollEvent(dx: Int, dy: Int, phase: ScrollPhase, momentumStart: Bool) -> CGEvent? {
        let event = CGEvent(
            scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx),
            wheel3: 0)
        event?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        // kCGScrollPhase: began 1, changed 2, ended 4. kCGMomentumScrollPhase: begin 1, continue 2, end 3.
        let (scrollPhase, momentumPhase): (Int64, Int64) =
            switch phase {
            case .began: (1, 0)
            case .changed: (2, 0)
            case .ended: (4, 0)
            case .momentum: (0, momentumStart ? 1 : 2)
            case .momentumEnded: (0, 3)
            }
        event?.setIntegerValueField(.scrollWheelEventScrollPhase, value: scrollPhase)
        event?.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentumPhase)
        return event
    }

    private func mouseEvent(for action: OutputAction) -> CGEvent? {
        let spec = MouseEventSpec(action)
        let event = CGEvent(
            mouseEventSource: source, mouseType: spec.type, mouseCursorPosition: CGPoint(x: spec.at.x, y: spec.at.y),
            mouseButton: spec.button == .left ? .left : .right)
        if spec.clickCount > 0 {
            event?.setIntegerValueField(.mouseEventClickState, value: Int64(spec.clickCount))
        }
        return event
    }
}

/// The CGEvent fields one mouse action needs.
private struct MouseEventSpec {
    var type: CGEventType
    var at: Point
    var button: MouseButton
    var clickCount: Int

    init(_ action: OutputAction) {
        switch action {
        case .moveCursor(let point): (type, at, button, clickCount) = (.mouseMoved, point, .left, 0)
        case .mouseDown(let button, let point, let count):
            (type, at, self.button, clickCount) = (
                button == .left ? .leftMouseDown : .rightMouseDown, point, button, count
            )
        case .mouseUp(let button, let point, let count):
            (type, at, self.button, clickCount) = (button == .left ? .leftMouseUp : .rightMouseUp, point, button, count)
        case .mouseDragged(let button, let point):
            (type, at, self.button, clickCount) = (
                button == .left ? .leftMouseDragged : .rightMouseDragged, point, button, 0
            )
        case .scroll, .keyStroke:
            (type, at, button, clickCount) = (.null, .zero, .left, 0)
        }
    }
}

/// Records actions instead of posting them (`handyctl inject --sink record`).
@MainActor
public final class RecordingSink: EventSink {
    public private(set) var actions: [OutputAction] = []

    public init() {}

    public func post(_ action: OutputAction) -> Bool {
        actions.append(action)
        return true
    }
}
