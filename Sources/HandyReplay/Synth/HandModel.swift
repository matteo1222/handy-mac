import Foundation
import HandyCore

/// A hand shape: how bent each finger is, where the thumb is, and how the hand is turned.
/// Shapes interpolate linearly, so a clip can blend from one pose to the next.
public struct HandShape: Sendable, Hashable {
    /// 0 straight, 1 fully curled into the palm. The thumb folds across the palm.
    public var curl: FingerValues
    /// 0 thumb free, 1 thumb tip touching the index tip.
    public var pinchIndex: Double
    /// 0 thumb free, 1 thumb tip touching the middle tip.
    public var pinchMiddle: Double
    /// Degrees about the vertical axis; 0 palm faces the camera, 90 side-on.
    public var yaw: Double
    /// Degrees in the image plane; positive turns the fingers toward the thumb side.
    public var roll: Double
    /// How much of a curl happens at the knuckle (MCP) versus the finger joints: 1 is the model's
    /// default; lower keeps the first phalanx straight and folds the fingertips, as in a loose fist.
    public var knuckleBend: Double
    /// Degrees of wrist flexion; positive tips the fingers toward the camera, so they foreshorten downward.
    public var pitch: Double

    public init(
        curl: FingerValues, pinchIndex: Double = 0, pinchMiddle: Double = 0, yaw: Double = 0, roll: Double = 0,
        knuckleBend: Double = 1, pitch: Double = 0
    ) {
        self.curl = curl
        self.pinchIndex = pinchIndex
        self.pinchMiddle = pinchMiddle
        self.yaw = yaw
        self.roll = roll
        self.knuckleBend = knuckleBend
        self.pitch = pitch
    }

    public func blended(to other: HandShape, _ u: Double) -> HandShape {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * u }
        return HandShape(
            curl: FingerValues { mix(curl[$0], other.curl[$0]) },
            pinchIndex: mix(pinchIndex, other.pinchIndex),
            pinchMiddle: mix(pinchMiddle, other.pinchMiddle),
            yaw: mix(yaw, other.yaw),
            roll: mix(roll, other.roll),
            knuckleBend: mix(knuckleBend, other.knuckleBend),
            pitch: mix(pitch, other.pitch))
    }
}

/// The pose library `handyctl synth` draws from.
public enum PoseName: String, Sendable, CaseIterable, Codable {
    case openPalm
    case relaxed
    case fist
    case pinch
    case nearPinch
    case pinchMiddle
    case point
    case twoFingers
    case thumbsUp
    case thumbsDown
    case shaka
    case typing
    case sideways
    /// Index finger bent down quickly, the others straight: the index-dip click.
    case indexDip
    /// Middle finger bent down: the index-dip family's right click.
    case middleDip
    /// An engaged hand at rest: fingers loosely bent, palm still toward the camera.
    case relaxedOpen

    public var shape: HandShape {
        func curls(_ thumb: Double, _ index: Double, _ middle: Double, _ ring: Double, _ little: Double)
            -> FingerValues
        {
            FingerValues(thumb: thumb, index: index, middle: middle, ring: ring, little: little)
        }
        return switch self {
        case .openPalm: HandShape(curl: curls(0, 0, 0, 0, 0))
        case .relaxed: HandShape(curl: curls(0.3, 0.35, 0.4, 0.45, 0.5), yaw: 25)
        case .fist: HandShape(curl: curls(0.9, 1, 1, 1, 1))
        case .pinch: HandShape(curl: curls(0, 0.3, 0.05, 0.05, 0.05), pinchIndex: 1)
        case .nearPinch: HandShape(curl: curls(0, 0.25, 0.05, 0.05, 0.05), pinchIndex: 0.55)
        case .pinchMiddle: HandShape(curl: curls(0, 0.05, 0.35, 0.05, 0.05), pinchMiddle: 1)
        case .point: HandShape(curl: curls(0.8, 0, 1, 1, 1))
        case .twoFingers: HandShape(curl: curls(0.8, 0, 0, 1, 1))
        case .thumbsUp: HandShape(curl: curls(0.05, 0.85, 0.85, 0.85, 0.85), roll: -90, knuckleBend: 0.6)
        case .thumbsDown: HandShape(curl: curls(0.05, 0.85, 0.85, 0.85, 0.85), roll: 90, knuckleBend: 0.6)
        case .shaka: HandShape(curl: curls(0.05, 0.85, 0.85, 0.85, 0.05), roll: -60, knuckleBend: 0.6)
        case .typing: HandShape(curl: curls(0.4, 0.55, 0.6, 0.6, 0.6), yaw: 10, roll: 0)
        case .sideways: HandShape(curl: curls(0, 0, 0, 0, 0), yaw: 80)
        case .indexDip: HandShape(curl: curls(0, 0.65, 0.05, 0.05, 0.05))
        case .middleDip: HandShape(curl: curls(0, 0.05, 0.65, 0.05, 0.05))
        case .relaxedOpen: HandShape(curl: curls(0.15, 0.35, 0.25, 0.25, 0.3))
        }
    }
}

/// An average right hand in hand units (wrist at the origin, wrist to middle MCP = 1),
/// palm facing the camera, fingers up, as seen in the mirrored image (thumb toward -x).
enum HandModel {
    struct Vector {
        var x: Double
        var y: Double
        var z: Double

        static func + (a: Vector, b: Vector) -> Vector { Vector(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
        static func * (a: Vector, k: Double) -> Vector { Vector(x: a.x * k, y: a.y * k, z: a.z * k) }
        static func += (a: inout Vector, b: Vector) { a = a + b }
    }

    /// Base position, straight direction (in the palm plane) and segment lengths of one finger.
    struct FingerSpec {
        var base: Vector
        var direction: (x: Double, y: Double)
        var segments: [Double]
    }

    static let fingers: [Finger: FingerSpec] = [
        .index: FingerSpec(base: Vector(x: -0.32, y: 0.95, z: 0), direction: (-0.12, 1), segments: [0.45, 0.27, 0.22]),
        .middle: FingerSpec(base: Vector(x: 0, y: 1, z: 0), direction: (0, 1), segments: [0.50, 0.30, 0.24]),
        .ring: FingerSpec(base: Vector(x: 0.27, y: 0.92, z: 0), direction: (0.1, 1), segments: [0.47, 0.28, 0.23]),
        .little: FingerSpec(base: Vector(x: 0.5, y: 0.8, z: 0), direction: (0.25, 1), segments: [0.36, 0.21, 0.19]),
    ]
    static let thumbBase = Vector(x: -0.28, y: 0.25, z: 0)
    static let thumbDirection = (x: -0.75, y: 0.66)
    static let thumbSegments = [0.33, 0.30, 0.26]

    /// Flexion per joint (MCP, PIP, DIP) at curl 1, in degrees, toward the camera.
    static let fullCurl = [85.0, 105.0, 70.0]

    /// 3D joint positions for a right hand in hand units.
    static func joints(_ shape: HandShape) -> [Vector] {
        var points = [Vector](repeating: Vector(x: 0, y: 0, z: 0), count: Joint.allCases.count)
        for (finger, spec) in fingers {
            let chain = chain(
                from: spec.base, direction: spec.direction, segments: spec.segments, curl: shape.curl[finger],
                knuckleBend: shape.knuckleBend)
            for (joint, point) in zip(finger.joints, chain) { points[joint.rawValue] = point }
        }
        var thumb = thumbChain(curl: shape.curl.thumb)
        for (amount, target) in [(shape.pinchIndex, Joint.indexTip), (shape.pinchMiddle, .middleTip)] where amount > 0 {
            thumb = reach(thumb, toward: points[target.rawValue], amount: amount)
        }
        for (joint, point) in zip(Finger.thumb.joints, thumb) { points[joint.rawValue] = point }
        return points
    }

    private static func chain(
        from base: Vector, direction: (x: Double, y: Double), segments: [Double], curl: Double,
        knuckleBend: Double = 1
    ) -> [Vector] {
        let norm = (direction.x * direction.x + direction.y * direction.y).squareRoot()
        let planar = Vector(x: direction.x / norm, y: direction.y / norm, z: 0)
        var points = [base]
        var angle = 0.0
        var current = base
        for (index, length) in segments.enumerated() {
            let bend = index == 0 ? knuckleBend : 1 + (1 - knuckleBend) * 0.35
            angle += fullCurl[index] * curl * bend * .pi / 180
            let step = planar * cos(angle) + Vector(x: 0, y: 0, z: -sin(angle))
            current += step * length
            points.append(current)
        }
        return points
    }

    /// The thumb sweeps from its open direction toward the palm centre as it curls.
    private static func thumbChain(curl: Double) -> [Vector] {
        let open = thumbDirection
        let across = (x: 0.85, y: 0.53)
        let direction = (x: open.x + (across.x - open.x) * curl, y: open.y + (across.y - open.y) * curl)
        var points = chain(from: thumbBase, direction: direction, segments: thumbSegments, curl: curl * 0.35)
        points[0] = thumbBase
        return points
    }

    /// Moves the thumb's distal joints toward a target, keeping the base fixed.
    private static func reach(_ thumb: [Vector], toward target: Vector, amount: Double) -> [Vector] {
        let gap = Vector(x: 0.03, y: 0.03, z: 0)
        let goal = target + gap
        let weights = [0.0, 0.35, 0.7, 1.0]
        return zip(thumb, weights).map { point, weight in
            let w = weight * amount
            return Vector(
                x: point.x + (goal.x - point.x) * w, y: point.y + (goal.y - point.y) * w,
                z: point.z + (goal.z - point.z) * w)
        }
    }
}

/// Where a hand sits in the frame.
public struct HandPlacement: Sendable, Hashable {
    public var chirality: Chirality
    /// The wrist position in frame-height units.
    public var wrist: Point
    /// Wrist to middle MCP length in frame-height units. About 0.15 at 0.6 m, 0.06 at 1.5 m, 0.03 at 3 m.
    public var size: Double

    public init(chirality: Chirality, wrist: Point, size: Double) {
        self.chirality = chirality
        self.wrist = wrist
        self.size = size
    }
}

extension HandShape {
    /// Projects the shape into the image: orthographic, mirrored for the left hand, rotated by yaw and roll.
    public func pose(at placement: HandPlacement, confidence: Double = 0.9) -> HandPose {
        let yawRadians = yaw * .pi / 180
        let rollRadians = roll * .pi / 180
        let pitchRadians = pitch * .pi / 180
        let mirror: Double = placement.chirality == .right ? 1 : -1
        let joints = HandModel.joints(self).map { joint -> JointSample? in
            var vector = joint
            (vector.y, vector.z) = (
                joint.y * cos(pitchRadians) + joint.z * sin(pitchRadians),
                -joint.y * sin(pitchRadians) + joint.z * cos(pitchRadians)
            )
            let yawed = vector.x * cos(yawRadians) + vector.z * sin(yawRadians)
            let x = yawed * mirror
            let rolledX = x * cos(rollRadians) - vector.y * sin(rollRadians) * mirror
            let rolledY = x * sin(rollRadians) * mirror + vector.y * cos(rollRadians)
            let point = Point(
                x: placement.wrist.x + rolledX * placement.size, y: placement.wrist.y - rolledY * placement.size)
            return JointSample(point, confidence: confidence)
        }
        return HandPose(chirality: placement.chirality, joints: joints)
    }
}
