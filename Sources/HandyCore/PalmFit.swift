import Foundation

/// Where the palm is, fitted from whichever palm points are visible.
///
/// A laptop camera often sees the fingers but not the wrist, and a knuckle can drop below the
/// confidence floor from one frame to the next. Fitting an average palm (wrist and four knuckles,
/// in hand units) to the visible ones with a least-squares similarity transform gives a hand scale,
/// a palm centroid that does not jump when a point drops out, and an estimate of a hidden wrist.
public struct PalmFit: Sendable, Hashable {
    /// Wrist to middle-finger knuckle, in frame heights.
    public var scale: Double
    /// Centre of the fitted wrist and knuckles.
    public var centroid: Point
    /// The fitted wrist (observed or estimated).
    public var wrist: Point
    /// Every fitted palm point, by joint.
    public var points: [Joint: Point]

    /// The average palm of a right hand in hand units (wrist at the origin, wrist to middle knuckle 1),
    /// in mirrored image orientation with y up. The same model the synthetic hand uses.
    static let model: [Joint: Point] = [
        .wrist: Point(x: 0, y: 0),
        .indexMCP: Point(x: -0.32, y: 0.95),
        .middleMCP: Point(x: 0, y: 1),
        .ringMCP: Point(x: 0.27, y: 0.92),
        .littleMCP: Point(x: 0.5, y: 0.8),
    ]

    /// Nil with fewer than two visible palm points.
    public init?(_ joints: [Joint: Point], chirality: Chirality) {
        let mirror: Double = chirality == .right ? 1 : -1
        // Model points in image orientation: mirror x for the left hand, flip y (image y points down).
        let modelImage = Self.model.mapValues { Point(x: $0.x * mirror, y: -$0.y) }
        let pairs = Self.model.keys.sorted { $0.rawValue < $1.rawValue }.compactMap { joint -> (Point, Point)? in
            guard let observed = joints[joint], let model = modelImage[joint] else { return nil }
            return (model, observed)
        }
        guard pairs.count >= 2 else { return nil }
        let modelMean = Point.mean(pairs.map(\.0))
        let observedMean = Point.mean(pairs.map(\.1))
        var a = 0.0
        var b = 0.0
        var norm = 0.0
        for (model, observed) in pairs {
            let m = model - modelMean
            let p = observed - observedMean
            a += m.x * p.x + m.y * p.y
            b += m.x * p.y - m.y * p.x
            norm += m.x * m.x + m.y * m.y
        }
        guard norm > 1e-12 else { return nil }
        let (sc, ss) = (a / norm, b / norm)  // scale·cos θ and scale·sin θ
        func transform(_ m: Point) -> Point {
            let d = m - modelMean
            return Point(x: observedMean.x + sc * d.x - ss * d.y, y: observedMean.y + ss * d.x + sc * d.y)
        }
        let fitted = modelImage.mapValues(transform)
        scale = (sc * sc + ss * ss).squareRoot()
        points = fitted
        wrist = fitted[.wrist] ?? observedMean
        centroid = Point.mean(Self.model.keys.compactMap { fitted[$0] })
    }

    /// `joints` with the hidden palm points filled in from the fit, and which ones were filled.
    public func filling(_ joints: [Point?]) -> (joints: [Point?], imputed: Set<Joint>) {
        var joints = joints
        var imputed: Set<Joint> = []
        for (joint, point) in points where joints[joint.rawValue] == nil {
            joints[joint.rawValue] = point
            imputed.insert(joint)
        }
        return (joints, imputed)
    }
}
