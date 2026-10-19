/// An event and the frame time it was emitted at.
public struct TimedEvent: Sendable, Equatable, Codable {
    public var t: Double
    public var event: Engine.Event

    public init(t: Double, event: Engine.Event) {
        self.t = t
        self.event = event
    }
}

/// Perception output to engine events: quality gate, identity, filtering, features, engine.
/// The same session type runs live in the app and headless in `handyctl replay`.
public struct Session: Sendable {
    public private(set) var engine: Engine
    public private(set) var lastFeatures: FrameFeatures?
    private var tracker: HandTracker
    private var extractor = FeatureExtractor()

    public init(engine: Engine = Engine(mode: .watching), tracker: HandTracker.Settings = .init()) {
        self.engine = engine
        self.tracker = HandTracker(settings: tracker)
    }

    public mutating func process(_ frame: LandmarkFrame) -> [TimedEvent] {
        let tracks = tracker.update(frame.hands, at: frame.t)
        let features = FrameFeatures(
            t: frame.t, hands: extractor.features(for: tracks, at: frame.t), face: frame.face)
        lastFeatures = features
        return engine.handle(.frame(features)).map { TimedEvent(t: frame.t, event: $0) }
    }

    /// New settings take effect from the next engage (recognizers keep theirs until then).
    public mutating func configure(_ settings: EngineSettings) {
        engine.settings = settings
    }

    public mutating func send(_ command: Engine.Command, at t: Double) -> [TimedEvent] {
        engine.handle(.command(command)).map { TimedEvent(t: t, event: $0) }
    }

    /// Forgets every track and filter, as after the camera stops.
    public mutating func resetTracking() {
        tracker.reset()
        extractor.reset()
    }
}
