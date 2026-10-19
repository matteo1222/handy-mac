/// Every gesture the engine recognises. Each case must have a replay fixture in
/// `Tests/HandyReplayTests/Fixtures/gestures/<case>.lmk` with `<case>.events.json`, or the
/// coverage test fails. Fixtures are synthesised by `scripts/fixtures.sh`.
public enum Gesture: String, Sendable, CaseIterable, Codable {
    /// Open palm held 300 ms.
    case engage
    /// A fist while engaged.
    case disengage
    /// Moving the open hand while engaged.
    case moveCursor
    /// Thumb-index pinch tap.
    case click
    /// Thumb-middle pinch tap.
    case rightClick
    /// Pinch held past 250 ms or moved past 8 pt, then released.
    case drag
    /// Two pinch taps within 350 ms.
    case doubleClick
    /// Index and middle up, moved; momentum on release.
    case scroll
    /// Both hands crossed, held 1 s: tracking off.
    case hardStop
}
