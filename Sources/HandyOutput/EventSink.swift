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
        switch action {
        case .moveCursor(let point):
            let location = CGPoint(x: point.x, y: point.y)
            guard
                let event = CGEvent(
                    mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: location,
                    mouseButton: .left)
            else { return false }
            event.post(tap: .cghidEventTap)
            return true
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
