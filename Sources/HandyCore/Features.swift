import Foundation

/// One value per finger.
public struct FingerValues: Sendable, Hashable, Codable {
    public var thumb: Double
    public var index: Double
    public var middle: Double
    public var ring: Double
    public var little: Double

    public init(thumb: Double, index: Double, middle: Double, ring: Double, little: Double) {
        self.thumb = thumb
        self.index = index
        self.middle = middle
        self.ring = ring
        self.little = little
    }

    public init(_ value: (Finger) -> Double) {
        self.init(
            thumb: value(.thumb), index: value(.index), middle: value(.middle), ring: value(.ring),
            little: value(.little))
    }

    public subscript(finger: Finger) -> Double {
        switch finger {
        case .thumb: thumb
        case .index: index
        case .middle: middle
        case .ring: ring
        case .little: little
        }
    }
}

/// Scale-free description of one tracked hand in one frame. Every distance is divided by
/// the hand scale (wrist to middle-finger MCP), so features do not change with distance.
public struct HandFeatures: Sendable, Hashable {
    public var id: Int
    public var chirality: Chirality
    /// Wrist to middle MCP, in normalised image units.
    public var scale: Double
    /// Thumb tip to index tip / scale. Nil when either tip is missing or below `minTipConfidence`.
    public var pinchIndex: Double?
    /// Thumb tip to middle tip / scale, with the same confidence rule.
    public var pinchMiddle: Double?
    /// How far each tip reaches past its base joint, measured from the wrist, / scale.
    /// About 0.7 to 1.0 when straight, near or below 0 when curled.
    public var reach: FingerValues
    /// Angle at each finger's middle joint (PIP; IP-ish for the thumb) in degrees. 180 is straight.
    public var curl: FingerValues
    /// Mean of the wrist and the four finger MCPs.
    public var palmCentroid: Point
    /// Index MCP to little MCP / scale. About 0.7 with the palm toward the camera, near 0 side-on,
    /// and negative when the back of the hand faces the camera (a hand resting flat on a leg or desk).
    public var palmFacing: Double
    /// Palm centroid velocity in normalised image units per second.
    public var velocity: Point
    /// Filtered joints, for classifiers and gesture rules that need raw geometry. Hidden palm
    /// points (often the wrist, below the frame) are filled in from the palm fit.
    public var joints: [Point?]
    public var jointConfidence: [Double]
    /// Joints in `joints` that were estimated from the palm fit rather than seen.
    public var imputed: Set<Joint> = []

    public subscript(joint: Joint) -> Point? { joints[joint.rawValue] }

    /// The joint only when the camera actually saw it.
    public func observed(_ joint: Joint) -> Point? { imputed.contains(joint) ? nil : self[joint] }

    /// Fingers count as extended above this `reach` value.
    public static let extendedThreshold = 0.45

    public func isExtended(_ finger: Finger) -> Bool { reach[finger] > Self.extendedThreshold }
}

/// Everything the engine sees for one frame.
public struct FrameFeatures: Sendable, Hashable {
    public var t: Double
    public var hands: [HandFeatures]
    public var face: FaceSample?

    public init(t: Double, hands: [HandFeatures], face: FaceSample? = nil) {
        self.t = t
        self.hands = hands
        self.face = face
    }
}

public struct FeatureExtractor: Sendable {
    /// A pinch is never inferred from a thumb or index tip below this confidence.
    public var minTipConfidence = 0.5
    /// Hands whose fingers reach farther than this (in hand scales) are not real hands: a straight
    /// finger reaches 0.7 to 1.0, and real tracking stays under 1.4 at the 99th percentile. A
    /// backend that invents a hand from a partly visible one (MediaPipe at a frame edge) reaches 2 to
    /// 7, and those hands opened palms and clicked on their own.
    public var maxReach = 1.5
    private var lastCentroid: [Int: (t: Double, point: Point)] = [:]

    public init() {}

    public mutating func reset() {
        lastCentroid = [:]
    }

    /// +1 when the palm faces the camera, -1 when the back of the hand does. Seen palm-first in the
    /// mirrored image, a right hand's index knuckle and little knuckle turn one way around the wrist;
    /// seen from the back, the other way. Rotation does not change the sign.
    public static func palmSide(wrist: Point, joints: [Point?], chirality: Chirality) -> Double {
        guard let index = joints[Joint.indexMCP.rawValue], let little = joints[Joint.littleMCP.rawValue] else {
            return 1
        }
        let a = index - wrist
        let b = little - wrist
        let turn: Double = a.x * b.y - a.y * b.x > 0 ? 1 : -1
        return chirality == .right ? turn : -turn
    }

    public func isPlausible(_ hand: HandFeatures) -> Bool {
        [Finger.index, .middle, .ring, .little].allSatisfy { hand.reach[$0] <= maxReach }
    }

    public mutating func features(for tracks: [HandTracker.Track], at t: Double) -> [HandFeatures] {
        let result = tracks.compactMap { features(for: $0, at: t) }.filter(isPlausible)
        lastCentroid = lastCentroid.filter { _, last in t - last.t < 0.5 }
        return result
    }

    private mutating func features(for track: HandTracker.Track, at t: Double) -> HandFeatures? {
        var palmPoints: [Joint: Point] = [:]
        for joint in PalmFit.model.keys { palmPoints[joint] = track[joint] }
        guard let fit = PalmFit(palmPoints, chirality: track.chirality) else { return nil }
        // Measured points win where visible; hidden palm points (often the wrist) come from the fit.
        let (joints, imputed) = fit.filling(track.joints)
        let wrist = track[.wrist] ?? fit.wrist
        let scale = max(
            track[.middleMCP].flatMap { mcp in track[.wrist].map { $0.distance(to: mcp) } } ?? fit.scale, 1e-6)
        let centroid = fit.centroid

        var velocity = Point.zero
        if let last = lastCentroid[track.id], t > last.t {
            velocity = (centroid - last.point) / (t - last.t)
        }
        lastCentroid[track.id] = (t, centroid)

        func point(_ joint: Joint) -> Point? { joints[joint.rawValue] }
        func tip(_ joint: Joint) -> Point? {
            track.confidence[joint.rawValue] >= minTipConfidence ? track[joint] : nil
        }
        func pinch(_ finger: Joint) -> Double? {
            guard let thumb = tip(.thumbTip), let other = tip(finger) else { return nil }
            return thumb.distance(to: other) / scale
        }
        let spread = point(.indexMCP).flatMap { index in point(.littleMCP).map { index.distance(to: $0) } }

        return HandFeatures(
            id: track.id,
            chirality: track.chirality,
            scale: scale,
            pinchIndex: pinch(.indexTip),
            pinchMiddle: pinch(.middleTip),
            reach: FingerValues { finger in
                guard let base = point(finger.base), let end = track[finger.tip] else { return 0 }
                return (wrist.distance(to: end) - wrist.distance(to: base)) / scale
            },
            curl: FingerValues { finger in
                let chain = finger.joints
                guard let a = point(chain[0]), let b = point(chain[1]), let c = point(chain[3]) else {
                    return 180
                }
                return Self.angle(at: b, from: a, to: c)
            },
            palmCentroid: centroid,
            palmFacing: (spread ?? 0) / scale * Self.palmSide(wrist: wrist, joints: joints, chirality: track.chirality),
            velocity: velocity,
            joints: joints,
            jointConfidence: track.confidence,
            imputed: imputed
        )
    }

    /// Interior angle at `vertex` in degrees.
    static func angle(at vertex: Point, from a: Point, to c: Point) -> Double {
        let u = a - vertex
        let v = c - vertex
        let denominator = u.length * v.length
        guard denominator > 1e-12 else { return 180 }
        let cosine = max(-1, min(1, (u.x * v.x + u.y * v.y) / denominator))
        return acos(cosine) * 180 / .pi
    }
}
