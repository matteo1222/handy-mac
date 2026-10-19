/// How palm motion becomes cursor motion.
public struct PointerSettings: Sendable, Hashable, Codable {
    /// A second 1€ filter on the palm centroid, tighter than the joint filter.
    public var filter = OneEuroSettings(minCutoff: 0.6, beta: 4)
    /// Points of cursor travel per frame height of palm travel when moving slowly (precision).
    public var slowGain = 1400.0
    /// Points per frame height when moving fast (crossing the screen).
    public var fastGain = 5200.0
    /// Palm speeds in frame heights per second where the gain starts and finishes rising.
    public var slowSpeed = 0.05
    public var fastSpeed = 0.6
    /// Moves smaller than this many points are dropped, so a still hand leaves the cursor still.
    public var deadband = 0.25

    public init() {}

    /// The trackpad-like acceleration curve: low gain when slow, high gain when fast,
    /// with a smooth ramp between.
    public func gain(atSpeed speed: Double) -> Double {
        let u = min(max((speed - slowSpeed) / (fastSpeed - slowSpeed), 0), 1)
        let eased = u * u * (3 - 2 * u)
        return slowGain + (fastGain - slowGain) * eased
    }
}

/// Turns successive palm centroids into relative cursor deltas. Starts fresh on every engage,
/// so re-engaging works like lifting a finger off a trackpad.
public struct PointerTracker: Sendable, Equatable {
    public var settings: PointerSettings
    private var filter: PointFilter
    private var last: TimedPoint?

    private struct TimedPoint: Sendable, Equatable {
        var t: Double
        var point: Point
    }

    public init(settings: PointerSettings) {
        self.settings = settings
        filter = PointFilter(settings: settings.filter)
    }

    /// Re-anchors without moving, for clutching and for unfreezing after a click.
    public mutating func reanchor(at centroid: Point, t: Double) {
        filter.reset()
        last = TimedPoint(t: t, point: filter.filter(centroid, at: t))
    }

    /// The cursor delta in points for this frame, or nil when it is below the deadband.
    public mutating func delta(for centroid: Point, at t: Double) -> Point? {
        step(for: centroid, at: t).cursor
    }

    /// One frame of filtered palm motion and the cursor delta it maps to.
    public struct Step: Sendable, Equatable {
        /// Filtered palm displacement in frame heights.
        public var motion: Point
        /// Accelerated cursor delta in points, or nil below the deadband.
        public var cursor: Point?
    }

    public mutating func step(for centroid: Point, at t: Double) -> Step {
        let filtered = filter.filter(centroid, at: t)
        defer { last = TimedPoint(t: t, point: filtered) }
        guard let last, t > last.t else { return Step(motion: .zero, cursor: nil) }
        let motion = filtered - last.point
        let speed = motion.length / (t - last.t)
        let delta = motion * settings.gain(atSpeed: speed)
        return Step(motion: motion, cursor: delta.length >= settings.deadband ? delta : nil)
    }
}

/// Edge snapping: within `band` points of a screen edge the cursor holds for `hold` seconds,
/// so the Dock, the menu bar and hot corners are easy to hit.
public struct EdgeStick: Sendable, Equatable {
    public var band = 24.0
    public var hold = 0.15
    private var stuckSince: Double?
    private var wasNearEdge = false

    public init() {}

    /// The new cursor position given the current one, a requested delta and the screen it is on.
    /// Coordinates are in points with the origin at the top-left of `screen`'s coordinate space.
    public mutating func apply(
        from position: Point, delta: Point, screen: Rect, at t: Double
    ) -> Point {
        if let stuckSince {
            if t - stuckSince < hold { return position }
            self.stuckSince = nil
        }
        let next = screen.clamp(position + delta)
        let near = screen.distanceToEdge(next) <= band
        if near, !wasNearEdge { stuckSince = t }
        wasNearEdge = near
        return next
    }
}

/// An axis-aligned rectangle in points, top-left origin.
public struct Rect: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public func contains(_ point: Point) -> Bool {
        point.x >= x && point.x < x + width && point.y >= y && point.y < y + height
    }

    public func clamp(_ point: Point) -> Point {
        Point(x: min(max(point.x, x), x + width - 1), y: min(max(point.y, y), y + height - 1))
    }

    public func distanceToEdge(_ point: Point) -> Double {
        min(point.x - x, x + width - 1 - point.x, point.y - y, y + height - 1 - point.y)
    }
}
