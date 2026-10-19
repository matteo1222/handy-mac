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
        guard let event = mouseEvent(for: action) else { return false }
        event.post(tap: .cghidEventTap)
        return true
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
