import Foundation

/// The static poses the classifier knows, plus the explicit "no gesture" class that every
/// one-shot must beat by a margin.
public enum PoseClass: String, Sendable, Codable, CaseIterable {
    case none
    case thumbsUp
    case thumbsDown
    case shaka
}

/// The classifier's input: one hand, normalised to a right hand with the wrist at the origin,
/// unit hand scale and the palm axis pointing up, plus the in-plane angle that normalisation
/// removed (thumbs up and thumbs down differ only by that angle) and each finger's reach.
public enum PoseFeatures {
    public static let count = 20 * 2 + 2 + 5

    public static func vector(_ hand: HandFeatures) -> [Double]? {
        guard let wrist = hand[.wrist], let middle = hand[.middleMCP] else { return nil }
        let mirror: Double = hand.chirality == .right ? 1 : -1
        let axis = (middle - wrist) / hand.scale
        let angle = atan2(axis.x * mirror, -axis.y)
        let (s, c) = (sin(-angle), cos(-angle))
        var vector: [Double] = []
        vector.reserveCapacity(count)
        for joint in Joint.allCases.dropFirst() {
            guard let point = hand[joint] else { return nil }
            let local = (point - wrist) / hand.scale
            let x = local.x * mirror
            let y = -local.y
            vector.append(x * c - y * s)
            vector.append(x * s + y * c)
        }
        vector.append(sin(angle))
        vector.append(cos(angle))
        vector += Finger.allCases.map { hand.reach[$0] }
        return vector
    }
}

/// A one-hidden-layer perceptron with a softmax output. Plain Swift arithmetic, so it gives the
/// same answer on every machine and replays deterministically.
public struct MLP: Sendable, Hashable, Codable {
    public var inputMean: [Double]
    public var inputScale: [Double]
    /// hidden × input, row-major.
    public var w1: [Double]
    public var b1: [Double]
    /// output × hidden, row-major.
    public var w2: [Double]
    public var b2: [Double]

    public init(inputMean: [Double], inputScale: [Double], w1: [Double], b1: [Double], w2: [Double], b2: [Double]) {
        self.inputMean = inputMean
        self.inputScale = inputScale
        self.w1 = w1
        self.b1 = b1
        self.w2 = w2
        self.b2 = b2
    }

    public var inputs: Int { inputMean.count }
    public var hidden: Int { b1.count }
    public var outputs: Int { b2.count }

    /// Hidden activations (tanh) for a normalised input.
    public func hiddenLayer(_ x: [Double]) -> [Double] {
        (0..<hidden).map { h in
            var sum = b1[h]
            let row = h * inputs
            for i in 0..<inputs { sum += w1[row + i] * x[i] }
            return tanh(sum)
        }
    }

    public func normalise(_ input: [Double]) -> [Double] {
        zip(zip(input, inputMean), inputScale).map { pair, scale in (pair.0 - pair.1) / scale }
    }

    public func probabilities(_ input: [Double]) -> [Double] {
        let h = hiddenLayer(normalise(input))
        let logits = (0..<outputs).map { o in
            var sum = b2[o]
            let row = o * hidden
            for j in 0..<hidden { sum += w2[row + j] * h[j] }
            return sum
        }
        return Self.softmax(logits)
    }

    public static func softmax(_ logits: [Double]) -> [Double] {
        let top = logits.max() ?? 0
        let exps = logits.map { exp($0 - top) }
        let total = exps.reduce(0, +)
        return exps.map { $0 / total }
    }
}

/// Class probabilities for one hand.
public struct PoseReading: Sendable, Equatable {
    public var probabilities: [PoseClass: Double]

    public init(probabilities: [PoseClass: Double]) {
        self.probabilities = probabilities
    }

    public var best: (pose: PoseClass, confidence: Double) {
        let top = probabilities.max { $0.value < $1.value } ?? (.none, 1)
        return (top.key, top.value)
    }

    public var noGesture: Double { probabilities[.none] ?? 0 }
}

public struct PoseClassifier: Sendable, Equatable {
    public let model: MLP
    public let classes: [PoseClass]

    public init(model: MLP, classes: [PoseClass]) {
        precondition(model.outputs == classes.count && model.inputs == PoseFeatures.count)
        self.model = model
        self.classes = classes
    }

    public func read(_ hand: HandFeatures) -> PoseReading? {
        guard let vector = PoseFeatures.vector(hand) else { return nil }
        let probabilities = model.probabilities(vector)
        return PoseReading(probabilities: Dictionary(uniqueKeysWithValues: zip(classes, probabilities)))
    }
}
