/// One OS-level input action, as HandyOutput would post it. Positions are global points with
/// a top-left origin (Quartz display coordinates). A value type so recordings can be diffed.
public enum OutputAction: Sendable, Equatable, Codable {
    case moveCursor(to: Point)
    /// `clickCount` is set on both down and up, so apps see double and triple clicks.
    case mouseDown(button: MouseButton, at: Point, clickCount: Int)
    case mouseUp(button: MouseButton, at: Point, clickCount: Int)
    case mouseDragged(button: MouseButton, to: Point)
}
