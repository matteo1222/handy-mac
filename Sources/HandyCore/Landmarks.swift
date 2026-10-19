/// A point in image coordinates measured in frame heights: origin top-left, x right, y down,
/// y in 0...1 and x in 0...aspect. Isotropic, so distances mean the same in both axes.
/// Already mirrored, so the image reads like a mirror to the user.
public struct Point: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Point(x: 0, y: 0)

    public static func + (a: Point, b: Point) -> Point { Point(x: a.x + b.x, y: a.y + b.y) }
    public static func - (a: Point, b: Point) -> Point { Point(x: a.x - b.x, y: a.y - b.y) }
    public static func * (a: Point, k: Double) -> Point { Point(x: a.x * k, y: a.y * k) }
    public static func / (a: Point, k: Double) -> Point { Point(x: a.x / k, y: a.y / k) }
    public static func += (a: inout Point, b: Point) { a = a + b }

    public var length: Double { (x * x + y * y).squareRoot() }

    public func distance(to other: Point) -> Double { (self - other).length }

    public static func mean(_ points: [Point]) -> Point {
        guard !points.isEmpty else { return .zero }
        return points.reduce(.zero, +) / Double(points.count)
    }
}

/// The 21 hand joints, in the order Vision and MediaPipe both use.
public enum Joint: Int, Sendable, CaseIterable, Codable {
    case wrist
    case thumbCMC, thumbMP, thumbIP, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}

public enum Finger: Int, Sendable, CaseIterable, Codable {
    case thumb, index, middle, ring, little

    /// Base to tip. For the thumb the base is the CMC joint.
    public var joints: [Joint] {
        let first = 1 + rawValue * 4
        return (first..<first + 4).compactMap(Joint.init(rawValue:))
    }

    public var base: Joint { joints[0] }
    public var middleJoint: Joint { joints[1] }
    public var tip: Joint { joints[3] }
}

public enum Chirality: String, Sendable, Codable, CaseIterable {
    case left
    case right

    public var other: Chirality { self == .left ? .right : .left }
}

public struct JointSample: Sendable, Hashable {
    public var point: Point
    public var confidence: Double

    public init(_ point: Point, confidence: Double = 1) {
        self.point = point
        self.confidence = confidence
    }
}

/// One hand as reported by a pose backend for one frame. Missing joints are nil.
public struct HandPose: Sendable, Hashable {
    public var chirality: Chirality
    public private(set) var joints: [JointSample?]

    public init(chirality: Chirality, joints: [JointSample?]) {
        precondition(joints.count == Joint.allCases.count, "a hand has 21 joints")
        self.chirality = chirality
        self.joints = joints
    }

    public subscript(joint: Joint) -> JointSample? {
        get { joints[joint.rawValue] }
        set { joints[joint.rawValue] = newValue }
    }
}

extension HandPose: Codable {
    private enum CodingKeys: String, CodingKey {
        case chirality = "c"
        case joints = "j"
    }

    /// Joints encode as `[x, y, confidence]` triples or null, to keep long recordings small.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(chirality, forKey: .chirality)
        try container.encode(joints.map { $0.map { [$0.point.x, $0.point.y, $0.confidence] } }, forKey: .joints)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let triples = try container.decode([[Double]?].self, forKey: .joints)
        guard triples.count == Joint.allCases.count, triples.allSatisfy({ $0 == nil || $0?.count == 3 }) else {
            throw DecodingError.dataCorruptedError(
                forKey: .joints, in: container, debugDescription: "expected 21 [x, y, confidence] triples or null")
        }
        self.init(
            chirality: try container.decode(Chirality.self, forKey: .chirality),
            joints: triples.map { $0.map { JointSample(Point(x: $0[0], y: $0[1]), confidence: $0[2]) } })
    }
}

/// A face measurement from the attention detector. `yaw` is nil when it looked and found no face.
public struct FaceSample: Sendable, Hashable, Codable {
    /// Degrees; 0 faces the camera, positive turns toward the user's right.
    public var yaw: Double?

    public init(yaw: Double?) {
        self.yaw = yaw
    }
}

/// Everything perception saw in one camera frame. Numbers only, never pixels.
public struct LandmarkFrame: Sendable, Hashable, Codable {
    /// Seconds from the start of the stream. The engine's only clock.
    public var t: Double
    public var hands: [HandPose]
    /// Present only on frames where the face detector ran.
    public var face: FaceSample?

    public init(t: Double, hands: [HandPose], face: FaceSample? = nil) {
        self.t = t
        self.hands = hands
        self.face = face
    }
}
