import CoreGraphics
import Foundation
import HandyCore

/// Draws a synthetic hand as a camera frame, so the real hand trackers (Vision, MediaPipe) can be
/// driven by a scripted hand: a skin-toned palm and forearm, fingers as tapered, shaded tubes drawn
/// back to front, on a plain background. The joints it draws from are the ground truth, so a test can
/// check both what the tracker saw and what the gesture engine did with it.
public enum HandRenderer {
    /// An RGB colour, components 0...1.
    public struct Color: Sendable, Hashable {
        public var red: Double
        public var green: Double
        public var blue: Double

        public init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// Each component scaled (darker below 1, lighter above), clamped to 1.
        func scaled(_ r: Double, _ g: Double, _ b: Double) -> Color {
            Color(red: min(red * r, 1), green: min(green * g, 1), blue: min(blue * b, 1))
        }

        func shaded(_ amount: Double) -> Color { scaled(amount, amount, amount) }
    }

    public struct Style: Sendable, Hashable {
        public var skin = Color(red: 0.87, green: 0.67, blue: 0.53)
        public var background = Color(red: 0.80, green: 0.81, blue: 0.83)
        /// Finger width at the knuckle, in hand lengths (wrist to middle knuckle).
        public var fingerWidth = 0.3

        public init() {}
    }

    /// One frame with `hands` drawn into a `width` × `height` image, in the camera's unmirrored view:
    /// the live path mirrors frames before tracking, so this image is flipped horizontally.
    public static func image(
        _ hands: [(shape: HandShape, placement: HandPlacement)], width: Int = 1280, height: Int = 720,
        style: Style = Style()
    ) -> CGImage? {
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        else { return nil }
        context.setFillColor(
            red: style.background.red, green: style.background.green, blue: style.background.blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for hand in hands {
            Painter(
                shape: hand.shape, placement: hand.placement, style: style, context: context,
                frame: CGSize(width: width, height: height)
            ).draw()
        }
        return context.makeImage()
    }

    struct Segment {
        var from: CGPoint
        var to: CGPoint
        var width: Double
        var depth: Double
    }

    struct Part {
        var depth: Double
        var segments: [Segment]
        /// Index into `Painter.chains`, nil for the forearm.
        var finger: Int?
    }

    /// Draws one hand. Everything is in pixels; the projected joints carry their depth so parts can
    /// be drawn back to front.
    struct Painter {
        let context: CGContext
        let points: [CGPoint]
        let depths: [Double]
        let size: Double
        let skin: Color
        let fingerWidth: Double
        /// Palms are lighter and pinker than the backs of hands, and creased; backs show nails.
        /// Trackers read which side faces them from these.
        let palmFacing: Bool

        static let chains: [[Joint]] = [
            [.thumbCMC, .thumbMP, .thumbIP, .thumbTip],
            [.indexMCP, .indexPIP, .indexDIP, .indexTip],
            [.middleMCP, .middlePIP, .middleDIP, .middleTip],
            [.ringMCP, .ringPIP, .ringDIP, .ringTip],
            [.littleMCP, .littlePIP, .littleDIP, .littleTip],
        ]
        static let palm: [Joint] = [.wrist, .thumbCMC, .indexMCP, .middleMCP, .ringMCP, .littleMCP]

        init(
            shape: HandShape, placement: HandPlacement, style: Style, context: CGContext, frame: CGSize
        ) {
            let projected = shape.projected(at: placement)
            let h = Double(frame.height)
            let w = Double(frame.width)
            // Frame heights (y down, mirrored view) to unmirrored pixels (y up).
            points = projected.map { CGPoint(x: w - $0.point.x * h, y: h - $0.point.y * h) }
            depths = projected.map(\.depth)
            let truth = projected.map(\.point) as [Point?]
            palmFacing =
                FeatureExtractor.palmSide(
                    wrist: projected[Joint.wrist.rawValue].point, joints: truth, chirality: placement.chirality) > 0
            skin = palmFacing ? style.skin.scaled(1.08, 1.1, 1.22) : style.skin
            size = placement.size * h
            fingerWidth = style.fingerWidth
            self.context = context
        }

        func p(_ joint: Joint) -> CGPoint { points[joint.rawValue] }
        func z(_ joint: Joint) -> Double { depths[joint.rawValue] }

        /// Parts drawn back to front, each one whole (outline, skin, highlight): a finger crossing the
        /// palm keeps its edge, and a finger's joints stay smooth rather than beaded.
        func draw() {
            let palmDepth = Self.palm.map(z).reduce(0, +) / Double(Self.palm.count)
            var palmDrawn = false
            for part in parts().sorted(by: { $0.depth > $1.depth }) {
                if !palmDrawn, part.depth < palmDepth {
                    drawPalm()
                    palmDrawn = true
                }
                for (scale, shade) in [(1.0, 0.74), (0.88, 1.0), (0.3, 1.1)] {
                    for segment in part.segments { stroke(segment, scale: scale, color: skin.shaded(shade)) }
                }
                if let finger = part.finger {
                    if palmFacing { drawFingerCreases(Self.chains[finger]) } else { drawNail(Self.chains[finger]) }
                }
            }
            if !palmDrawn { drawPalm() }
        }

        func parts() -> [Part] {
            // Forearm: from the wrist away from the middle knuckle, out of the frame.
            let wrist = p(.wrist)
            let middle = p(.middleMCP)
            let away = CGPoint(x: wrist.x - (middle.x - wrist.x) * 3, y: wrist.y - (middle.y - wrist.y) * 3)
            var parts = [Part(depth: 1, segments: [Segment(from: wrist, to: away, width: 0.92 * size, depth: 1)])]
            for (index, chain) in Self.chains.enumerated() {
                let base = fingerWidth * size * (index == 0 ? 1.15 : index == 4 ? 0.82 : 1.0)
                let segments = (0..<3).map { k in
                    Segment(
                        from: p(chain[k]), to: p(chain[k + 1]), width: base * (0.94 - 0.12 * Double(k)),
                        depth: (z(chain[k]) + z(chain[k + 1])) / 2)
                }
                // A finger lies just in front of the palm it grows from unless it curls behind it.
                let depth = segments.map(\.depth).reduce(0, +) / 3 - 0.05
                parts.append(Part(depth: depth, segments: segments, finger: index))
            }
            return parts
        }

        /// The palm: the knuckle polygon swelled by a thick round stroke, so it is as wide as a real palm.
        func drawPalm() {
            let path = CGMutablePath()
            path.addLines(between: Self.palm.map(p))
            path.closeSubpath()
            for (grow, shade) in [(1.0, 0.74), (0.88, 1.0)] {
                let color = skin.shaded(shade)
                context.setLineJoin(.round)
                context.setLineWidth(0.42 * size * grow)
                context.setStrokeColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
                context.setFillColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
                context.addPath(path)
                context.drawPath(using: .fillStroke)
            }
            if palmFacing { drawPalmCreases() }
        }

        func stroke(_ segment: Segment, scale: Double, color: Color) {
            line([segment.from, segment.to], width: segment.width * scale, color: color)
        }

        func line(_ points: [CGPoint], width: Double, color: Color) {
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(width)
            context.setStrokeColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
            context.addLines(between: points)
            context.strokePath()
        }

        func mix(_ a: Joint, _ b: Joint, _ t: Double) -> CGPoint {
            let (pa, pb) = (p(a), p(b))
            return CGPoint(x: pa.x + (pb.x - pa.x) * t, y: pa.y + (pb.y - pa.y) * t)
        }

        var crease: Color { skin.scaled(0.66, 0.52, 0.5) }

        /// Heart, head and life lines across the palm.
        func drawPalmCreases() {
            let width = 0.035 * size
            line(
                [
                    mix(.littleMCP, .wrist, 0.25), mix(.ringMCP, .wrist, 0.22), mix(.middleMCP, .wrist, 0.25),
                    mix(.indexMCP, .wrist, 0.2),
                ], width: width, color: crease)
            line(
                [mix(.littleMCP, .wrist, 0.45), mix(.middleMCP, .wrist, 0.42), mix(.indexMCP, .thumbCMC, 0.5)],
                width: width, color: crease)
            line(
                [mix(.indexMCP, .thumbCMC, 0.55), mix(.thumbCMC, .wrist, 0.35), mix(.wrist, .middleMCP, 0.08)],
                width: width, color: crease)
        }

        /// A crease across each of a finger's two middle joints.
        func drawFingerCreases(_ chain: [Joint]) {
            for k in 1...2 {
                let c = p(chain[k])
                let before = p(chain[k - 1])
                let along = CGPoint(x: c.x - before.x, y: c.y - before.y)
                let length = max((along.x * along.x + along.y * along.y).squareRoot(), 1)
                let across = CGPoint(x: -along.y / length * 0.1 * size, y: along.x / length * 0.1 * size)
                line(
                    [CGPoint(x: c.x - across.x, y: c.y - across.y), CGPoint(x: c.x + across.x, y: c.y + across.y)],
                    width: 0.028 * size, color: crease)
            }
        }

        func drawNail(_ chain: [Joint]) {
            let ends = [mix(chain[2], chain[3], 0.45), mix(chain[2], chain[3], 0.92)]
            line(ends, width: 0.16 * size, color: skin.scaled(0.82, 0.74, 0.72))
            line(ends, width: 0.12 * size, color: skin.scaled(1.1, 1.04, 1.06))
        }
    }
}

extension HandShape {
    /// The 21 joints projected like `pose(at:)`, with each joint's depth (larger is farther from the
    /// camera), for drawing them back to front.
    public func projected(at placement: HandPlacement) -> [(point: Point, depth: Double)] {
        let yawRadians = yaw * .pi / 180
        let rollRadians = roll * .pi / 180
        let pitchRadians = pitch * .pi / 180
        let mirror: Double = placement.chirality == .right ? 1 : -1
        return HandModel.joints(self).map { joint in
            let y = joint.y * cos(pitchRadians) + joint.z * sin(pitchRadians)
            let z = -joint.y * sin(pitchRadians) + joint.z * cos(pitchRadians)
            let yawed = joint.x * cos(yawRadians) + z * sin(yawRadians)
            let depth = -joint.x * sin(yawRadians) + z * cos(yawRadians)
            let x = yawed * mirror
            let rolledX = x * cos(rollRadians) - y * sin(rollRadians) * mirror
            let rolledY = x * sin(rollRadians) * mirror + y * cos(rollRadians)
            return (
                Point(x: placement.wrist.x + rolledX * placement.size, y: placement.wrist.y - rolledY * placement.size),
                depth
            )
        }
    }
}
