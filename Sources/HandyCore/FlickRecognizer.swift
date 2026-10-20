public enum Direction: String, Sendable, Codable, CaseIterable {
    case up
    case down
    case left
    case right

    /// Unit vector in image coordinates (y down).
    public var unit: Point {
        switch self {
        case .up: Point(x: 0, y: -1)
        case .down: Point(x: 0, y: 1)
        case .left: Point(x: -1, y: 0)
        case .right: Point(x: 1, y: 0)
        }
    }
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
    /// A flick starts from rest: in this long before it, the tip moved less than `restTravel` hand scales.
    /// Gesturing while talking keeps the hand moving, so it rarely shows the still-then-snap of a flick.
    public var rest = 0.15
    public var restTravel = 0.15
    /// A flick ends still pointing and at rest: it fires only after the pose has held still this long
    /// past the travel, so a hand leaving the pose mid-turn, or a wag, does not fire.
    public var confirm = 0.1
    /// Per-frame tip motion (hand scales) below which the tip counts as settled.
    public var settled = 0.05
    /// Motion back against the flick (hand scales per frame) that marks a wag and cancels it.
    public var reversal = 0.1

    public init() {}
}

/// Index-finger flicks in four directions, from the pointing pose, while not engaged.
///
/// A flick is the fingertip moving relative to the wrist (a quick wrist turn or tip), measured in
/// hand scales. Moving the whole hand while pointing, as people do when talking, moves the wrist
/// with the tip and does not count.
public struct FlickRecognizer: Sendable, Equatable {
    public var settings: FlickSettings
    private var history: [Sample] = []
    private var poseSince: Double?
    private var quietUntil = -Double.infinity
    private var pending: Pending?

    struct Pending: Sendable, Equatable {
        var direction: Direction
        var at: Double
        var tip: Point
        var scale: Double
    }

    struct Sample: Sendable, Equatable {
        var t: Double
        /// Index tip relative to the wrist, in frame heights.
        var tip: Point
        var scale: Double
    }

    public init(settings: FlickSettings) {
        self.settings = settings
    }

    public mutating func reset() {
        history = []
        poseSince = nil
        pending = nil
    }

    /// Feed the pointer hand (or nil when absent); returns the direction that fires on this frame.
    public mutating func update(_ hand: HandFeatures?, at t: Double) -> Direction? {
        guard let hand, Self.isPointing(hand), let indexTip = hand[.indexTip],
            // A fitted wrist shifts as knuckles drop in and out, which would read as tip motion.
            let wrist = hand.observed(.wrist)
        else {
            reset()
            return nil
        }
        let since = poseSince ?? t
        poseSince = since
        // Normalise by the scale at the start of the window: tipping the hand foreshortens the palm
        // as much as the finger, so dividing by the current scale would hide the flick.
        let tip = indexTip - wrist
        if var pending {
            // Wait for the fingertip to settle; swinging back (a wag) cancels the flick.
            let step = (tip - pending.tip) / pending.scale
            let along = step.x * pending.direction.unit.x + step.y * pending.direction.unit.y
            if along < -settings.reversal {
                self.pending = nil
                return nil
            }
            if step.length > settings.settled {
                pending.tip = tip
                pending.at = t
                self.pending = pending
                return nil
            }
            guard t - pending.at >= settings.confirm else { return nil }
            self.pending = nil
            return pending.direction
        }
        history.append(Sample(t: t, tip: tip, scale: hand.scale))
        history.removeAll { t - $0.t > settings.window + settings.rest }
        guard t >= quietUntil, t - since >= settings.settle + settings.rest,
            let first = history.first(where: { t - $0.t <= settings.window })
        else { return nil }
        let before = history.filter { $0.t <= first.t && first.t - $0.t <= settings.rest }
        let restless = before.contains { ($0.tip - first.tip).length / first.scale > settings.restTravel }
        guard !restless else { return nil }
        let travel = (tip - first.tip) / first.scale
        let along = max(abs(travel.x), abs(travel.y))
        let across = min(abs(travel.x), abs(travel.y))
        guard along >= settings.distance, along >= settings.dominance * across else { return nil }
        quietUntil = t + settings.refractory
        history = []
        let direction: Direction =
            abs(travel.x) > abs(travel.y) ? (travel.x > 0 ? .right : .left) : (travel.y > 0 ? .down : .up)
        pending = Pending(direction: direction, at: t, tip: tip, scale: first.scale)
        return nil
    }

    /// Clearly pointing: the index well extended and the other three well curled. A margin on both
    /// sides of the "extended" line keeps a loosely relaxed hand from counting.
    public static func isPointing(_ hand: HandFeatures) -> Bool {
        hand.reach.index > 0.6 && [Finger.middle, .ring, .little].allSatisfy { hand.reach[$0] < 0.2 }
    }
}
