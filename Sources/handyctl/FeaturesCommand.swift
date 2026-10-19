import ArgumentParser
import Foundation
import HandyCore
import HandyReplay

struct Features: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the per-frame hand features HandyCore computes for a .lmk clip."
    )

    @Argument(help: "The .lmk clip.")
    var clip: String

    @Option(help: "Print every Nth frame.")
    var every: Int = 1

    func run() throws {
        let stream = try LandmarkStream(contentsOf: URL(filePath: clip))
        var session = Session()
        var rows: [FeatureRow] = []
        for (index, frame) in stream.frames.enumerated() {
            _ = session.process(frame)
            guard index % max(every, 1) == 0, let features = session.lastFeatures else { continue }
            rows.append(FeatureRow(features))
        }
        try printJSON(rows)
    }
}

/// A rounded, flat view of `FrameFeatures` for reading and diffing.
struct FeatureRow: Codable, Equatable {
    struct Hand: Codable, Equatable {
        let id: Int
        let chirality: Chirality
        let scale: Double
        let pinchIndex: Double?
        let pinchMiddle: Double?
        let reach: [Double]
        let curl: [Double]
        let palm: [Double]
        let palmFacing: Double
        let velocity: [Double]
    }

    let t: Double
    let hands: [Hand]
    let faceYaw: Double?

    init(_ features: FrameFeatures) {
        func r(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
        t = r(features.t)
        faceYaw = features.face?.yaw.map(r)
        hands = features.hands.map { hand in
            Hand(
                id: hand.id, chirality: hand.chirality, scale: r(hand.scale),
                pinchIndex: hand.pinchIndex.map(r), pinchMiddle: hand.pinchMiddle.map(r),
                reach: Finger.allCases.map { r(hand.reach[$0]) },
                curl: Finger.allCases.map { r(hand.curl[$0]) },
                palm: [r(hand.palmCentroid.x), r(hand.palmCentroid.y)],
                palmFacing: r(hand.palmFacing),
                velocity: [r(hand.velocity.x), r(hand.velocity.y)])
        }
    }
}
