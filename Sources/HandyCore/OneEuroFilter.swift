import Foundation

/// The 1€ filter (Casiez et al. 2012): low jitter when still, low lag when moving fast.
/// Tune `minCutoff` first with the hand still, then `beta` while moving.
public struct OneEuroSettings: Sendable, Hashable, Codable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double

    public init(minCutoff: Double, beta: Double, derivativeCutoff: Double = 1) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    /// Joint positions in normalised image units.
    public static let joints = OneEuroSettings(minCutoff: 1.5, beta: 8)
}

public struct OneEuroFilter: Sendable, Equatable {
    public var settings: OneEuroSettings
    private struct Sample: Sendable, Equatable {
        var t: Double
        var value: Double
        var derivative: Double
    }

    private var last: Sample?

    public init(settings: OneEuroSettings) {
        self.settings = settings
    }

    public mutating func reset() {
        last = nil
    }

    public mutating func filter(_ value: Double, at t: Double) -> Double {
        guard let last else {
            self.last = Sample(t: t, value: value, derivative: 0)
            return value
        }
        guard t > last.t else { return last.value }
        let dt = t - last.t
        let derivative = Self.smooth(
            (value - last.value) / dt, previous: last.derivative, alpha: Self.alpha(settings.derivativeCutoff, dt))
        let cutoff = settings.minCutoff + settings.beta * abs(derivative)
        let filtered = Self.smooth(value, previous: last.value, alpha: Self.alpha(cutoff, dt))
        self.last = Sample(t: t, value: filtered, derivative: derivative)
        return filtered
    }

    private static func alpha(_ cutoff: Double, _ dt: Double) -> Double {
        let tau = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + tau / dt)
    }

    private static func smooth(_ value: Double, previous: Double, alpha: Double) -> Double {
        alpha * value + (1 - alpha) * previous
    }
}

/// A 1€ filter per axis of a 2D point.
public struct PointFilter: Sendable, Equatable {
    private var x: OneEuroFilter
    private var y: OneEuroFilter

    public init(settings: OneEuroSettings) {
        x = OneEuroFilter(settings: settings)
        y = OneEuroFilter(settings: settings)
    }

    public mutating func filter(_ point: Point, at t: Double) -> Point {
        Point(x: x.filter(point.x, at: t), y: y.filter(point.y, at: t))
    }

    public mutating func reset() {
        x.reset()
        y.reset()
    }
}
