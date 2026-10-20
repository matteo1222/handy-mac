import Foundation
import HandyCore

public struct LabelledSample: Sendable {
    public var features: [Double]
    public var label: PoseClass
}

/// Labelled pose samples generated from the synthetic hand model with randomised shapes,
/// orientation, placement, size and joint noise. A stand-in until HaGRID landmarks are added.
public enum PoseDataset {
    public static func synthetic(count: Int, seed: UInt64, noiseRange: ClosedRange<Double> = 0...3) -> [LabelledSample]
    {
        var random = SeededRandom(seed: seed)
        var samples: [LabelledSample] = []
        samples.reserveCapacity(count)
        let labels = PoseClass.allCases
        while samples.count < count {
            // Half the data is "no gesture": it is the class every one-shot has to beat.
            let label = random.unit() < 0.5 ? PoseClass.none : labels[1 + Int(random.unit() * Double(labels.count - 1))]
            var shape = randomShape(for: label, random: &random)
            shape.knuckleBend = 0.2 + random.unit()
            let chirality: Chirality = random.unit() < 0.7 ? .right : .left
            let placement = HandPlacement(
                chirality: chirality,
                wrist: Point(x: 0.4 + random.unit() * 1.0, y: 0.55 + random.unit() * 0.35),
                size: 0.04 + random.unit() * 0.14)
            var pose = shape.pose(at: placement)
            let sigma = (noiseRange.lowerBound + random.unit() * (noiseRange.upperBound - noiseRange.lowerBound)) / 720
            for joint in Joint.allCases {
                guard var sample = pose[joint] else { continue }
                sample.point = Point(
                    x: sample.point.x + random.gaussian() * sigma, y: sample.point.y + random.gaussian() * sigma)
                pose[joint] = sample
            }
            var session = Session()
            _ = session.process(LandmarkFrame(t: 0, hands: [pose]))
            guard let hand = session.lastFeatures?.hands.first, let vector = PoseFeatures.vector(hand) else { continue }
            samples.append(LabelledSample(features: vector, label: label))
        }
        return samples
    }

    /// Real thumbs-up and thumbs-down are fists rolled about 90° (fingers pointing sideways, thumb up
    /// or down), seen from the palm or the back. A shaka is anywhere from upright to rolled sideways.
    static func randomShape(for label: PoseClass, random: inout SeededRandom) -> HandShape {
        func around(_ value: Double, _ spread: Double) -> Double { value + (random.unit() * 2 - 1) * spread }
        // Real curled fingers range from loosely bent to tight in a fist.
        func curled() -> Double { 0.6 + random.unit() * 0.4 }
        func straight() -> Double { max(0, around(0.08, 0.1)) }
        func view() -> Double { random.unit() < 0.5 ? around(0, 35) : around(180, 35) }
        switch label {
        case .thumbsUp, .thumbsDown:
            let roll = label == .thumbsUp ? around(90, 30) : around(-90, 30)
            return HandShape(
                curl: FingerValues(
                    thumb: straight(), index: curled(), middle: curled(), ring: curled(), little: curled()),
                yaw: view(), roll: roll)
        case .shaka:
            return HandShape(
                curl: FingerValues(
                    thumb: straight(), index: curled(), middle: curled(), ring: curled(), little: straight()),
                yaw: view(), roll: around(45, 65))
        case .none:
            return noGestureShape(random: &random)
        }
    }

    /// Everyday hands: the other library poses, plus random finger mixes that do not match a class.
    static func noGestureShape(random: inout SeededRandom) -> HandShape {
        func around(_ value: Double, _ spread: Double) -> Double { value + (random.unit() * 2 - 1) * spread }
        let library: [PoseName] = [
            .openPalm, .relaxed, .fist, .pinch, .nearPinch, .pinchMiddle, .point, .twoFingers, .typing, .sideways,
        ]
        if random.unit() < 0.6 {
            var shape = library[Int(random.unit() * Double(library.count))].shape
            shape.yaw = random.unit() < 0.7 ? around(shape.yaw, 30) : around(180, 35)
            shape.roll = around(shape.roll, 100)
            return shape
        }
        while true {
            let curl = FingerValues { _ in random.unit() }
            let fingersCurled = [curl.index, curl.middle, curl.ring].allSatisfy { $0 > 0.5 }
            let looksLikeAClass = fingersCurled && curl.thumb < 0.35
            if looksLikeAClass { continue }
            return HandShape(
                curl: curl, yaw: random.unit() < 0.7 ? around(20, 50) : around(180, 35), roll: around(0, 120))
        }
    }
}
