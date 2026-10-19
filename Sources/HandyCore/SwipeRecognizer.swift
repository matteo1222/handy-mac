public struct SwipeSettings: Sendable, Hashable, Codable {
    /// Palm travel needed, as a fraction of the frame's width (left/right) or height (up)...
    public var distance = 0.25
    /// ...within this long.
    public var window = 0.4
    /// The travel must be this many times longer on its main axis than across it.
    public var dominance = 2.0
    /// After firing, swipes are ignored this long.
    public var refractory = 0.6

    public init() {}
}

/// Open-palm swipes while not engaged: left and right for Spaces, up for Mission Control.
public struct SwipeRecognizer: Sendable, Equatable {
    public var settings: SwipeSettings
    private var history: [Sample] = []
    private var quietUntil = -Double.infinity

    struct Sample: Sendable, Equatable {
        var t: Double
        var palm: Point
    }

    public init(settings: SwipeSettings) {
        self.settings = settings
    }

    public mutating func reset() {
        history = []
    }

    /// True during the refractory after a swipe, when arming is also held off.
    public func isQuiet(at t: Double) -> Bool { t < quietUntil }

    /// Feed the pointer hand when it shows an open palm (nil otherwise). `aspect` is frame width over height.
    public mutating func update(openPalm hand: HandFeatures?, aspect: Double, at t: Double) -> Direction? {
        guard let hand else {
            history = []
            return nil
        }
        history.append(Sample(t: t, palm: hand.palmCentroid))
        history.removeAll { t - $0.t > settings.window }
        guard t >= quietUntil, let first = history.first else { return nil }
        let travel = hand.palmCentroid - first.palm
        let horizontal = abs(travel.x) / aspect
        let vertical = abs(travel.y)
        let direction: Direction?
        if horizontal >= settings.distance, abs(travel.x) >= settings.dominance * abs(travel.y) {
            direction = travel.x > 0 ? .right : .left
        } else if vertical >= settings.distance, travel.y < 0, abs(travel.y) >= settings.dominance * abs(travel.x) {
            direction = .up
        } else {
            direction = nil
        }
        guard let direction else { return nil }
        quietUntil = t + settings.refractory
        history = []
        return direction
    }
}
