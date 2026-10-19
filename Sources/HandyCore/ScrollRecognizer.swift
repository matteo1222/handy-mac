/// Trackpad-style scroll phases, as apps see them on real scroll-wheel events.
public enum ScrollPhase: String, Sendable, Codable, CaseIterable {
    case began
    case changed
    case ended
    case momentum
    case momentumEnded
}

public struct ScrollSettings: Sendable, Hashable, Codable {
    /// The scroll pose must hold this long to start scrolling.
    public var enterDwell = 0.15
    /// The pose may be lost this long before scrolling ends.
    public var exitDwell = 0.15
    /// Points of content travel per frame height of palm travel. Fixed, not accelerated.
    public var gain = 3000.0
    /// Momentum velocity is multiplied by this every frame after release.
    public var momentumDecay = 0.92
    /// Momentum stops below this many points per frame.
    public var momentumStop = 0.5
    /// After release the hand is still slowing down; pointing motion only stops momentum after this.
    public var momentumGrace = 0.25
    /// Weight of the newest frame in the scroll velocity average.
    public var velocitySmoothing = 0.5

    public init() {}
}

/// Two-finger scroll with momentum. Content follows the hand, like natural trackpad scrolling.
public struct ScrollRecognizer: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case idle(poseSince: Double?)
        case scrolling(poseLostSince: Double?, velocity: Point)
        case momentum(velocity: Point, since: Double)
    }

    public var settings: ScrollSettings
    public private(set) var phase: Phase = .idle(poseSince: nil)

    public init(settings: ScrollSettings) {
        self.settings = settings
    }

    public var isScrolling: Bool {
        if case .scrolling = phase { return true }
        return false
    }

    /// True while the recognizer owns the hand's motion (scrolling or coasting), so the cursor parks.
    public var ownsMotion: Bool {
        if case .idle = phase { return false }
        return true
    }

    /// Advances one frame. `motion` is filtered palm displacement in frame heights; `cursorMoved`
    /// says the hand is clearly pointing again, which stops momentum.
    public mutating func update(isScrollPose: Bool, motion: Point, cursorMoved: Bool, at t: Double) -> [Engine.Event] {
        switch phase {
        case .idle(let poseSince):
            guard isScrollPose else {
                phase = .idle(poseSince: nil)
                return []
            }
            let since = poseSince ?? t
            if t - since >= settings.enterDwell {
                phase = .scrolling(poseLostSince: nil, velocity: .zero)
                return [.scroll(dx: 0, dy: 0, phase: .began)]
            }
            phase = .idle(poseSince: since)
            return []

        case .scrolling(let lostSince, let velocity):
            if isScrollPose {
                let delta = motion * settings.gain
                let smoothed = delta * settings.velocitySmoothing + velocity * (1 - settings.velocitySmoothing)
                phase = .scrolling(poseLostSince: nil, velocity: smoothed)
                return delta == .zero ? [] : [.scroll(dx: delta.x, dy: delta.y, phase: .changed)]
            }
            let since = lostSince ?? t
            guard t - since >= settings.exitDwell else {
                phase = .scrolling(poseLostSince: since, velocity: currentVelocity)
                return []
            }
            let velocity = currentVelocity * settings.momentumDecay
            guard velocity.length >= settings.momentumStop else {
                phase = .idle(poseSince: nil)
                return [.scroll(dx: 0, dy: 0, phase: .ended)]
            }
            phase = .momentum(velocity: velocity, since: t)
            return [.scroll(dx: 0, dy: 0, phase: .ended), .scroll(dx: velocity.x, dy: velocity.y, phase: .momentum)]

        case .momentum(let velocity, let since):
            if isScrollPose || (cursorMoved && t - since >= settings.momentumGrace) {
                phase = .idle(poseSince: isScrollPose ? t : nil)
                return [.scroll(dx: 0, dy: 0, phase: .momentumEnded)]
            }
            let next = velocity * settings.momentumDecay
            guard next.length >= settings.momentumStop else {
                phase = .idle(poseSince: nil)
                return [.scroll(dx: 0, dy: 0, phase: .momentumEnded)]
            }
            phase = .momentum(velocity: next, since: since)
            return [.scroll(dx: next.x, dy: next.y, phase: .momentum)]
        }
    }

    /// Stops scrolling or coasting immediately, for disengaging.
    public mutating func cancel() -> [Engine.Event] {
        defer { phase = .idle(poseSince: nil) }
        switch phase {
        case .idle: return []
        case .scrolling: return [.scroll(dx: 0, dy: 0, phase: .ended)]
        case .momentum: return [.scroll(dx: 0, dy: 0, phase: .momentumEnded)]
        }
    }

    private var currentVelocity: Point {
        if case .scrolling(_, let velocity) = phase { return velocity }
        return .zero
    }
}
