/// Every gesture the engine recognises. Each case must have a replay fixture in
/// `Tests/HandyReplayTests/Fixtures/gestures/<case>.lmk` with `<case>.events.json`, or the
/// coverage test fails.
public enum Gesture: Sendable, CaseIterable {}
