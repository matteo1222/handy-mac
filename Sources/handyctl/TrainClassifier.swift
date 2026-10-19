import ArgumentParser
import Foundation
import HandyCore
import HandyReplay

struct TrainClassifier: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "train-classifier",
        abstract: "Train the pose classifier, evaluate it on a held-out split and write its weights as Swift.",
        discussion: """
            Training data is synthetic (the hand model with randomised poses, placement and noise) until
            HaGRID landmarks are added. The held-out split uses a different seed and more noise.
            """)

    @Option(help: "Training samples.")
    var samples = 16000

    @Option(help: "Held-out samples.")
    var heldOut = 3000

    @Option(help: "Random seed.")
    var seed: UInt64 = 1

    @Option(help: "Training epochs.")
    var epochs = 80

    @Option(help: "Hidden units.")
    var hidden = 32

    @Option(help: "Where to write the generated weights.")
    var output = "Sources/HandyCore/PoseClassifierWeights.swift"

    @Option(help: "Where to write the evaluation report (JSON).")
    var report = "docs/pose-classifier-report.json"

    func run() throws {
        let classes = PoseClass.allCases
        let train = PoseDataset.synthetic(count: samples, seed: seed)
        let test = PoseDataset.synthetic(count: heldOut, seed: seed &+ 1_000_003, noiseRange: 1...4)
        var trainer = MLPTrainer()
        trainer.hidden = hidden
        trainer.epochs = epochs
        trainer.seed = seed
        let model = trainer.train(train, classes: classes)
        let classifier = PoseClassifier(model: model, classes: classes)
        let evaluation = ClassifierReport.evaluate(
            classifier, on: test, trainSamples: train.count, data: "synthetic hand model, seed \(seed)")
        let note =
            "Synthetic training data, seed \(seed), \(samples) samples, \(hidden) hidden units, \(epochs) epochs."
        try model.swiftSource(classes: classes, note: note).write(toFile: output, atomically: true, encoding: .utf8)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (encoder.encode(evaluation) + Data("\n".utf8)).write(to: URL(filePath: report))
        try printJSON(evaluation)
    }
}
