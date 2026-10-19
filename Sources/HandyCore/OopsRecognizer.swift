public struct OopsSettings: Sendable, Hashable, Codable {
    /// Direction reversals of the wagging fingertip needed...
    public var reversals = 3
    /// ...within this long.
    public var window = 1.2
    /// Each swing must cover at least this many hand scales sideways.
    public var swing = 0.3
    /// After firing, the wag is ignored this long.
    public var refractory = 1.0

    public init() {}
}

/// The "no-no" index-finger wag while not engaged: undo, and remember what went wrong.
/// Sideways fingertip motion is measured relative to the wrist, like a flick.
public struct OopsRecognizer: Sendable, Equatable {
    public var settings: OopsSettings
    private var anchor: Double?
    private var direction: Double = 0
    private var turns: [Double] = []
    private var quietUntil = -Double.infinity

    public init(settings: OopsSettings) {
        self.settings = settings
    }

    public mutating func reset() {
        anchor = nil
        direction = 0
        turns = []
    }

    /// Feed the pointer hand; returns true on the frame the wag completes.
    public mutating func update(_ hand: HandFeatures?, at t: Double) -> Bool {
        guard let hand, FlickRecognizer.isPointing(hand), let tip = hand[.indexTip], let wrist = hand[.wrist] else {
            reset()
            return false
        }
        let x = (tip.x - wrist.x) / hand.scale
        guard let anchor else {
            self.anchor = x
            return false
        }
        let travel = x - anchor
        if direction == 0 {
            if abs(travel) >= settings.swing { (direction, self.anchor) = (travel > 0 ? 1 : -1, x) }
        } else if travel * direction > 0 {
            self.anchor = x  // still swinging the same way: follow the extreme
        } else if abs(travel) >= settings.swing {
            turns.append(t)
            (direction, self.anchor) = (-direction, x)
        }
        turns.removeAll { t - $0 > settings.window }
        guard t >= quietUntil, turns.count >= settings.reversals else { return false }
        quietUntil = t + settings.refractory
        reset()
        return true
    }
}
