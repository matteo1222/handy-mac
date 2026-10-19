/// One OS-level input action, as HandyOutput would post it. Positions are global points with
/// a top-left origin (Quartz display coordinates). A value type so recordings can be diffed.
public enum OutputAction: Sendable, Equatable, Codable {
    case moveCursor(to: Point)
}
