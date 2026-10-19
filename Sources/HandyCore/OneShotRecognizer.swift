public struct OneShotSettings: Sendable, Hashable, Codable {
    /// The pose's probability must exceed this...
    public var minConfidence = 0.9
    /// ...and beat the "no gesture" class by this much...
    public var margin = 0.3
    /// ...continuously for this long.
    public var hold = 0.5

    public init() {}
}

/// Fires a static pose once it has been held confidently for the hold time, then waits for the
/// pose to end before it can fire again, so holding a thumbs-up presses Return once.
public struct OneShotRecognizer: Sendable, Equatable {
    public var settings: OneShotSettings
    private var candidate: Candidate?
    private var latched: PoseClass?
    /// Set after disengaging: a hand that was pointing a moment ago must relax before it can fire.
    private var blocked = false

    struct Candidate: Sendable, Equatable {
        var pose: PoseClass
        var since: Double
    }

    public init(settings: OneShotSettings) {
        self.settings = settings
    }

    /// The pose that qualifies in this reading, if any.
    public func qualifying(_ reading: PoseReading?) -> PoseClass? {
        guard let reading else { return nil }
        let best = reading.best
        guard best.pose != .none, best.confidence > settings.minConfidence,
            best.confidence - reading.noGesture >= settings.margin
        else { return nil }
        return best.pose
    }

    /// Returns the pose that fires on this frame.
    public mutating func update(_ reading: PoseReading?, at t: Double) -> PoseClass? {
        guard let pose = qualifying(reading) else {
            candidate = nil
            latched = nil
            blocked = false
            return nil
        }
        if blocked { return nil }
        if pose == latched { return nil }
        latched = nil
        let since = candidate?.pose == pose ? candidate?.since ?? t : t
        candidate = Candidate(pose: pose, since: since)
        guard t - since >= settings.hold else { return nil }
        candidate = nil
        latched = pose
        return pose
    }

    public mutating func reset() {
        candidate = nil
        latched = nil
    }

    /// Ignores every pose until the hand shows no qualifying pose for a frame.
    public mutating func blockUntilRelease() {
        reset()
        blocked = true
    }

    /// The pose being held and how far through the hold it is, for the HUD's progress arc.
    public func progress(at t: Double) -> (pose: PoseClass, fraction: Double)? {
        guard let candidate else { return nil }
        return (candidate.pose, min(max((t - candidate.since) / settings.hold, 0), 1))
    }
}

/// Maps engine events to actions through the user's bindings. Pure, so it replays.
public struct ActionRouter: Sendable {
    public var bindings: Bindings

    public init(bindings: Bindings = .defaults) {
        self.bindings = bindings
    }

    public func actions(for event: Engine.Event) -> [Action] {
        switch event {
        case .oneShot(let pose): bindings.oneShots[pose].map { [$0] } ?? []
        case .flick(let direction): bindings.flicks[direction].map { [$0] } ?? []
        case .swipe(let direction): bindings.swipes[direction].map { [$0] } ?? []
        case .zoom(let direction): bindings.zooms[direction].map { [$0] } ?? []
        default: []
        }
    }
}
