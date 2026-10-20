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

    @Option(
        help: "HaGRID landmarks (.jsonl from scripts/hagrid-landmarks.py) to train and test on with the synthetic set.")
    var hagrid: String?

    @Option(help: "Where to write the generated weights.")
    var output = "Sources/HandyCore/PoseClassifierWeights.swift"

    @Option(help: "Where to write the evaluation report (JSON).")
    var report = "docs/pose-classifier-report.json"

    func run() throws {
        let classes = PoseClass.allCases
        var train = PoseDataset.synthetic(count: samples, seed: seed)
        var test = PoseDataset.synthetic(count: heldOut, seed: seed &+ 1_000_003, noiseRange: 1...4)
        var data = "synthetic hand model, seed \(seed)"
        var realTest: [LabelledSample] = []
        if let hagrid {
            let url = URL(filePath: hagrid)
            let real = try HaGRID.samples(from: url, split: "train")
            realTest = try HaGRID.samples(from: url, split: "test")
            train += real
            test += realTest
            data += " + HaGRID (CC BY-SA 4.0): \(real.count) train, \(realTest.count) held-out by subject"
        }
        var trainer = MLPTrainer()
        trainer.hidden = hidden
        trainer.epochs = epochs
        trainer.seed = seed
        let model = trainer.train(train, classes: classes)
        let classifier = PoseClassifier(model: model, classes: classes)
        var evaluation = ClassifierReport.evaluate(classifier, on: test, trainSamples: train.count, data: data)
        if !realTest.isEmpty {
            evaluation.subsets = [
                "hagrid": ClassifierReport.evaluate(
                    classifier, on: realTest, trainSamples: train.count, data: "HaGRID held-out subjects")
            ]
        }
        let note =
            "Training data: \(data); \(train.count) samples, \(hidden) hidden units, \(epochs) epochs."
            + (hagrid == nil ? "" : " Weights derived from HaGRID are offered under CC BY-SA 4.0.")
        try model.swiftSource(classes: classes, note: note).write(toFile: output, atomically: true, encoding: .utf8)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (encoder.encode(evaluation) + Data("\n".utf8)).write(to: URL(filePath: report))
        try printJSON(evaluation)
    }
}
