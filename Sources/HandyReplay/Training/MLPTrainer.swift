import Foundation
import HandyCore

/// Trains `MLP` with minibatch SGD, momentum and L2, on standardised inputs. Deterministic for a seed.
public struct MLPTrainer {
    public var hidden = 24
    public var epochs = 60
    public var batch = 32
    public var learningRate = 0.05
    public var momentum = 0.9
    public var l2 = 1e-4
    public var seed: UInt64 = 1

    public init() {}

    public func train(_ samples: [LabelledSample], classes: [PoseClass]) -> MLP {
        let inputs = samples[0].features.count
        let outputs = classes.count
        let mean = (0..<inputs).map { i in samples.reduce(0) { $0 + $1.features[i] } / Double(samples.count) }
        let scale = (0..<inputs).map { i -> Double in
            let variance = samples.reduce(0) { $0 + pow($1.features[i] - mean[i], 2) } / Double(samples.count)
            return max(variance.squareRoot(), 1e-6)
        }
        var random = SeededRandom(seed: seed)
        let limit1 = (6.0 / Double(inputs + hidden)).squareRoot()
        let limit2 = (6.0 / Double(hidden + outputs)).squareRoot()
        var model = MLP(
            inputMean: mean, inputScale: scale,
            w1: (0..<hidden * inputs).map { _ in (random.unit() * 2 - 1) * limit1 },
            b1: Array(repeating: 0, count: hidden),
            w2: (0..<outputs * hidden).map { _ in (random.unit() * 2 - 1) * limit2 },
            b2: Array(repeating: 0, count: outputs))
        var velocity = Gradient(inputs: inputs, hidden: hidden, outputs: outputs)
        let normalised = samples.map { model.normalise($0.features) }
        let targets = samples.map { classes.firstIndex(of: $0.label) ?? 0 }
        var order = Array(samples.indices)

        for _ in 0..<epochs {
            for i in stride(from: order.count - 1, to: 0, by: -1) {
                order.swapAt(i, Int(random.next() % UInt64(i + 1)))
            }
            for start in stride(from: 0, to: order.count, by: batch) {
                var gradient = Gradient(inputs: inputs, hidden: hidden, outputs: outputs)
                let indices = order[start..<min(start + batch, order.count)]
                for index in indices {
                    accumulate(&gradient, model: model, x: normalised[index], target: targets[index])
                }
                let step = learningRate / Double(indices.count)
                velocity.update(with: gradient, model: model, momentum: momentum, step: step, l2: l2)
                velocity.apply(to: &model)
            }
        }
        return model
    }

    private func accumulate(_ gradient: inout Gradient, model: MLP, x: [Double], target: Int) {
        let h = model.hiddenLayer(x)
        let logits = (0..<model.outputs).map { o in
            (0..<model.hidden).reduce(model.b2[o]) { $0 + model.w2[o * model.hidden + $1] * h[$1] }
        }
        let p = MLP.softmax(logits)
        var dh = Array(repeating: 0.0, count: model.hidden)
        for o in 0..<model.outputs {
            let d = p[o] - (o == target ? 1 : 0)
            gradient.b2[o] += d
            for j in 0..<model.hidden {
                gradient.w2[o * model.hidden + j] += d * h[j]
                dh[j] += d * model.w2[o * model.hidden + j]
            }
        }
        for j in 0..<model.hidden {
            let d = dh[j] * (1 - h[j] * h[j])
            gradient.b1[j] += d
            let row = j * model.inputs
            for i in 0..<model.inputs { gradient.w1[row + i] += d * x[i] }
        }
    }
}

private struct Gradient {
    var w1: [Double]
    var b1: [Double]
    var w2: [Double]
    var b2: [Double]

    init(inputs: Int, hidden: Int, outputs: Int) {
        w1 = Array(repeating: 0, count: inputs * hidden)
        b1 = Array(repeating: 0, count: hidden)
        w2 = Array(repeating: 0, count: hidden * outputs)
        b2 = Array(repeating: 0, count: outputs)
    }

    /// Momentum update: self is the velocity.
    mutating func update(with gradient: Gradient, model: MLP, momentum: Double, step: Double, l2: Double) {
        for i in w1.indices { w1[i] = momentum * w1[i] - step * (gradient.w1[i] + l2 * model.w1[i]) }
        for i in b1.indices { b1[i] = momentum * b1[i] - step * gradient.b1[i] }
        for i in w2.indices { w2[i] = momentum * w2[i] - step * (gradient.w2[i] + l2 * model.w2[i]) }
        for i in b2.indices { b2[i] = momentum * b2[i] - step * gradient.b2[i] }
    }

    func apply(to model: inout MLP) {
        for i in w1.indices { model.w1[i] += w1[i] }
        for i in b1.indices { model.b1[i] += b1[i] }
        for i in w2.indices { model.w2[i] += w2[i] }
        for i in b2.indices { model.b2[i] += b2[i] }
    }
}

/// Held-out metrics: per-class precision and recall of the argmax, and the rate at which
/// no-gesture samples would fire a one-shot under the engine's confidence and margin rule.
public struct ClassifierReport: Codable, Sendable {
    public struct ClassMetrics: Codable, Sendable {
        public var precision: Double
        public var recall: Double
        public var support: Int
    }

    public var data: String
    public var trainSamples: Int
    public var heldOutSamples: Int
    public var accuracy: Double
    public var perClass: [String: ClassMetrics]
    /// Fraction of no-gesture samples that pass the one-shot rule for some pose.
    public var noGestureFalsePositiveRate: Double
    /// Fraction of pose samples that pass the one-shot rule for their own pose.
    public var oneShotRecall: [String: Double]

    public static func evaluate(
        _ classifier: PoseClassifier, on samples: [LabelledSample], trainSamples: Int, data: String,
        rule: OneShotRecognizer = OneShotRecognizer(settings: OneShotSettings())
    ) -> ClassifierReport {
        let readings = samples.map { sample -> (PoseClass, PoseReading) in
            let p = classifier.model.probabilities(sample.features)
            return (
                sample.label, PoseReading(probabilities: Dictionary(uniqueKeysWithValues: zip(classifier.classes, p)))
            )
        }
        func round(_ value: Double) -> Double { (value * 10_000).rounded() / 10_000 }
        var perClass: [String: ClassMetrics] = [:]
        for pose in classifier.classes {
            let predicted = readings.filter { $0.1.best.pose == pose }
            let actual = readings.filter { $0.0 == pose }
            let hits = predicted.filter { $0.0 == pose }.count
            perClass[pose.rawValue] = ClassMetrics(
                precision: round(predicted.isEmpty ? 0 : Double(hits) / Double(predicted.count)),
                recall: round(actual.isEmpty ? 0 : Double(hits) / Double(actual.count)), support: actual.count)
        }
        let none = readings.filter { $0.0 == .none }
        let falsePositives = none.filter { rule.qualifying($0.1) != nil }.count
        var oneShotRecall: [String: Double] = [:]
        for pose in classifier.classes where pose != .none {
            let actual = readings.filter { $0.0 == pose }
            let fired = actual.filter { rule.qualifying($0.1) == pose }.count
            oneShotRecall[pose.rawValue] = round(actual.isEmpty ? 0 : Double(fired) / Double(actual.count))
        }
        let correct = readings.filter { label, reading in label == reading.best.pose }.count
        let accuracy = round(Double(correct) / Double(readings.count))
        return ClassifierReport(
            data: data, trainSamples: trainSamples, heldOutSamples: samples.count, accuracy: accuracy,
            perClass: perClass,
            noGestureFalsePositiveRate: round(none.isEmpty ? 0 : Double(falsePositives) / Double(none.count)),
            oneShotRecall: oneShotRecall)
    }
}

extension MLP {
    /// The weights as a Swift source file, so inference needs no resources and no Core ML.
    public func swiftSource(classes: [PoseClass], note: String) -> String {
        func list(_ values: [Double]) -> String {
            values.map { String(format: "%.6g", $0) }.joined(separator: ", ")
        }
        return """
            // swift-format-ignore-file
            // Generated by `handyctl train-classifier`. Do not edit by hand.
            // \(note)

            extension PoseClassifier {
                public static let standard = PoseClassifier(
                    model: MLP(
                        inputMean: [\(list(inputMean))],
                        inputScale: [\(list(inputScale))],
                        w1: [\(list(w1))],
                        b1: [\(list(b1))],
                        w2: [\(list(w2))],
                        b2: [\(list(b2))]),
                    classes: [\(classes.map { "." + $0.rawValue }.joined(separator: ", "))])
            }

            """
    }
}
