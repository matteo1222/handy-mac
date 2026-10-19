import HandyCore

/// Integrates a replay's cursor moves into positions, to measure jitter and travel headlessly.
public enum CursorTrace {
    public struct Sample: Sendable, Equatable {
        public var t: Double
        public var position: Point
        public var engaged: Bool
    }

    /// One sample per frame, starting from the origin.
    public static func run(_ stream: LandmarkStream, session: Session = Session()) -> [Sample] {
        var session = session
        var position = Point.zero
        return stream.frames.map { frame in
            for timed in session.process(frame) {
                if case .moveCursor(let dx, let dy) = timed.event { position += Point(x: dx, y: dy) }
            }
            return Sample(t: frame.t, position: position, engaged: session.engine.mode == .engaged)
        }
    }

    /// Root-mean-square distance from the mean position, in points, over engaged samples after `settle` seconds.
    public static func jitter(_ samples: [Sample], settle: Double = 0.5) -> Double {
        guard let engagedAt = samples.first(where: \.engaged)?.t else { return 0 }
        let still = samples.filter { $0.engaged && $0.t >= engagedAt + settle }.map(\.position)
        guard !still.isEmpty else { return 0 }
        let mean = Point.mean(still)
        let squares = still.map { ($0.x - mean.x) * ($0.x - mean.x) + ($0.y - mean.y) * ($0.y - mean.y) }
        return (squares.reduce(0, +) / Double(squares.count)).squareRoot()
    }
}
