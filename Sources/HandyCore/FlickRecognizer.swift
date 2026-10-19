public enum Direction: String, Sendable, Codable, CaseIterable {
    case up
    case down
    case left
    case right
}

public struct FlickSettings: Sendable, Hashable, Codable {
    /// Index-tip travel, in hand scales, that counts as a flick...
    public var distance = 0.6
    /// ...when covered within this window.
    public var window = 0.25
    /// The travel must be this many times longer on its main axis than across it.
    public var dominance = 2.0
    /// After firing, flicks are ignored this long.
    public var refractory = 0.4
    /// The index-only pose must be held this long before a flick counts.
    public var settle = 0.1

    public init() {}
}

/// Index-finger flicks in four directions, from the pointing pose, while not engaged.
public struct FlickRecognizer: Sendable, Equatable {
    public var settings: FlickSettings
    private var history: [Sample] = []
    private var poseSince: Double?
    private var quietUntil = -Double.infinity

    struct Sample: Sendable, Equatable {
        var t: Double
        var tip: Point
    }

    public init(settings: FlickSettings) {
        self.settings = settings
    }

    public mutating func reset() {
        history = []
        poseSince = nil
    }

    /// Feed the pointer hand (or nil when absent); returns the direction that fires on this frame.
    public mutating func update(_ hand: HandFeatures?, at t: Double) -> Direction? {
        guard let hand, Self.isPointing(hand), let tip = hand[.indexTip] else {
            reset()
            return nil
        }
        let since = poseSince ?? t
        poseSince = since
        history.append(Sample(t: t, tip: tip))
        history.removeAll { t - $0.t > settings.window }
        guard t >= quietUntil, t - since >= settings.settle, let first = history.first else { return nil }
        let travel = (tip - first.tip) / hand.scale
        let along = max(abs(travel.x), abs(travel.y))
        let across = min(abs(travel.x), abs(travel.y))
        guard along >= settings.distance, along >= settings.dominance * across else { return nil }
        quietUntil = t + settings.refractory
        history = []
        if abs(travel.x) > abs(travel.y) { return travel.x > 0 ? .right : .left }
        return travel.y > 0 ? .down : .up
    }

    /// Index extended, the other three fingers curled.
    public static func isPointing(_ hand: HandFeatures) -> Bool {
        hand.isExtended(.index) && ![Finger.middle, .ring, .little].contains(where: hand.isExtended)
    }
}
