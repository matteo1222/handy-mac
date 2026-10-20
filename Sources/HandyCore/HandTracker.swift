/// Turns raw per-frame hand poses into tracked, filtered hands with stable identities.
///
/// Quality gate: joints under `minJointConfidence` are dropped and hands with fewer than
/// `minValidJoints` or fewer than two visible palm points are rejected. Identity: each hand matches
/// the nearest previous wrist, observed or fitted from the knuckles when out of view.
/// A hand missing for longer than `trackGrace` loses its track, and its filters start fresh.
public struct HandTracker: Sendable {
    public struct Settings: Sendable, Hashable, Codable {
        public var minJointConfidence = 0.3
        public var minValidJoints = 15
        /// Normalised image units; a wrist that jumps further than this is a new hand.
        public var maxWristJump = 0.25
        /// A hand missing for less than this keeps its identity and filters (tracking dropouts).
        public var trackGrace = 0.25
        public var filter = OneEuroSettings.joints

        public init() {}
    }

    /// A hand after gating and filtering. Joint positions are filtered; missing joints stay nil.
    public struct Track: Sendable, Hashable {
        public let id: Int
        public let chirality: Chirality
        public let joints: [Point?]
        public let confidence: [Double]

        public subscript(joint: Joint) -> Point? { joints[joint.rawValue] }
    }

    private struct State: Sendable {
        let id: Int
        var chirality: Chirality
        var wrist: Point
        var lastSeen: Double
        var filters: [PointFilter]
    }

    public var settings: Settings
    private var tracks: [State] = []
    private var nextID = 1

    public init(settings: Settings = Settings()) {
        self.settings = settings
    }

    public mutating func reset() {
        tracks = []
    }

    public mutating func update(_ hands: [HandPose], at t: Double) -> [Track] {
        let gated = hands.compactMap(gate)
        var unclaimed = tracks
        var next: [State] = []
        var output: [Track] = []
        for hand in gated {
            guard let wrist = hand[.wrist]?.point ?? Self.palmFit(hand)?.wrist else { continue }
            var state: State
            if let index = nearest(to: wrist, in: unclaimed) {
                state = unclaimed.remove(at: index)
                state.chirality = hand.chirality
            } else {
                state = State(
                    id: nextID, chirality: hand.chirality, wrist: wrist, lastSeen: t,
                    filters: Array(repeating: PointFilter(settings: settings.filter), count: Joint.allCases.count))
                nextID += 1
            }
            var filtered: [Point?] = []
            for joint in Joint.allCases {
                guard let sample = hand[joint] else {
                    filtered.append(nil)
                    continue
                }
                filtered.append(state.filters[joint.rawValue].filter(sample.point, at: t))
            }
            state.wrist = filtered[Joint.wrist.rawValue] ?? wrist
            state.lastSeen = t
            next.append(state)
            output.append(
                Track(
                    id: state.id, chirality: state.chirality, joints: filtered,
                    confidence: hand.joints.map { $0?.confidence ?? 0 }))
        }
        tracks = next + unclaimed.filter { t - $0.lastSeen < settings.trackGrace }
        return output
    }

    private func gate(_ hand: HandPose) -> HandPose? {
        var gated = hand
        for joint in Joint.allCases where (hand[joint]?.confidence ?? 0) < settings.minJointConfidence {
            gated[joint] = nil
        }
        let valid = gated.joints.compactMap { $0 }.count
        guard valid >= settings.minValidJoints, Self.palmFit(gated) != nil else { return nil }
        return gated
    }

    /// The most recently seen track within reach, nearest first among equals. A track still being
    /// followed frame to frame wins over a stale one held through a dropout, even if the stale one
    /// is a little closer, so a fast-moving hand cannot be handed to an old identity.
    /// The palm fitted to a hand's visible palm points (the wrist is often out of a laptop camera's view).
    static func palmFit(_ hand: HandPose) -> PalmFit? {
        var points: [Joint: Point] = [:]
        for joint in PalmFit.model.keys { points[joint] = hand[joint]?.point }
        return PalmFit(points, chirality: hand.chirality)
    }

    private func nearest(to wrist: Point, in candidates: [State]) -> Int? {
        candidates.indices
            .filter { candidates[$0].wrist.distance(to: wrist) <= settings.maxWristJump }
            .min { a, b in
                let (left, right) = (candidates[a], candidates[b])
                if left.lastSeen != right.lastSeen { return left.lastSeen > right.lastSeen }
                return left.wrist.distance(to: wrist) < right.wrist.distance(to: wrist)
            }
    }
}
