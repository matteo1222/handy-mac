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
    /// Thumbs up held 500 ms while not engaged: Return.
    case thumbsUp
    /// Thumbs down held 500 ms while not engaged: Esc.
    case thumbsDown
    /// Index-finger flicks while not engaged: arrow keys.
    case flickUp
    case flickDown
    case flickLeft
    case flickRight
    /// Open-palm swipes while not engaged: previous and next Space, Mission Control.
    case swipeLeft
    case swipeRight
    case swipeUp
    /// Two-hand pinch spread / close while engaged.
    case zoomIn
    case zoomOut
    /// Shaka held 500 ms while not engaged: toggles Dictation.
    case dictation
    /// "No-no" index-finger wag while not engaged: ⌘Z and a false-positive sample.
    case oops
    /// Other hand pinch-holds while engaged, then moves toward one of eight slots.
    case palette
}
