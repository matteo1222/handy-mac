import Foundation
import HandyCore

/// Noise applied to a clean clip to mimic a real camera.
public struct SynthNoise: Sendable, Equatable {
    /// Gaussian jitter per joint, in pixels of a 720-pixel-high frame.
    public var jitterPixels: Double
    /// Probability that a frame loses the whole hand.
    public var dropout: Double
    /// Probability that a joint reports low confidence (0.1) in a frame, as in dim light.
    public var confidenceLoss: Double
    /// Joints that always report `dimConfidence`, e.g. fingertips hidden from a front camera.
    public var dimJoints: Set<Joint>
    public var dimConfidence: Double
    public var seed: UInt64

    public init(
        jitterPixels: Double = 0, dropout: Double = 0, confidenceLoss: Double = 0, dimJoints: Set<Joint> = [],
        dimConfidence: Double = 0.4, seed: UInt64 = 1
    ) {
        self.jitterPixels = jitterPixels
        self.dropout = dropout
        self.confidenceLoss = confidenceLoss
        self.dimJoints = dimJoints
        self.dimConfidence = dimConfidence
        self.seed = seed
    }

    public static let none = SynthNoise()
}

/// SplitMix64: tiny, seedable and identical on every platform, so clips are reproducible.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }

    mutating func gaussian() -> Double {
        let u1 = max(unit(), 1e-12)
        let u2 = unit()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

public enum Synthesizer {
    public static let defaultSize = 0.15
    public static let defaultWrist = Point(x: 0.9, y: 0.75)

    public static func render(_ clip: Clip, noise: SynthNoise = .none) -> [LandmarkFrame] {
        var frames: [LandmarkFrame] = []
        forEachFrame(clip, noise: noise) { frames.append($0) }
        return frames
    }

    /// Renders frame by frame without holding the clip in memory, for long corpora.
    public static func forEachFrame(_ clip: Clip, noise: SynthNoise = .none, _ body: (LandmarkFrame) -> Void) {
        var random = SeededRandom(seed: noise.seed)
        var cursors = clip.hands.map { TrackCursor(track: $0) }
        var faceCursor = 0
        var faceElapsed = 0.0
        let count = Int((clip.duration * clip.fps).rounded(.down)) + 1
        for index in 0..<count {
            let t = Double(index) / clip.fps
            var hands: [HandPose] = []
            for i in cursors.indices {
                guard var pose = cursors[i].sample(at: t, transition: clip.transition) else { continue }
                if noise.dropout > 0, random.unit() < noise.dropout { continue }
                pose = perturb(pose, noise: noise, random: &random)
                hands.append(pose)
            }
            var face: FaceSample?
            // The face detector runs at 5 fps; only every sixth 30 fps frame carries a reading.
            if !clip.face.isEmpty, index % max(Int(clip.fps / 5), 1) == 0 {
                while faceCursor < clip.face.count - 1, t >= faceElapsed + clip.face[faceCursor].duration {
                    faceElapsed += clip.face[faceCursor].duration
                    faceCursor += 1
                }
                face = FaceSample(yaw: clip.face[faceCursor].yaw)
            }
            body(LandmarkFrame(t: rounded(t), hands: hands, face: face))
        }
    }

    /// Walks one hand track forward in time; frames must be sampled in increasing order.
    struct TrackCursor {
        let track: Clip.HandTrack
        var index = 0
        var elapsed = 0.0
        var position = Synthesizer.defaultWrist
        var size = Synthesizer.defaultSize
        var previousShape: HandShape?

        init(track: Clip.HandTrack) {
            self.track = track
            if let first = track.steps.first {
                position = first.start ?? position
                size = first.size ?? size
            }
        }

        mutating func sample(at t: Double, transition: Double) -> HandPose? {
            while index < track.steps.count - 1, t >= elapsed + track.steps[index].duration {
                let step = track.steps[index]
                position = step.end ?? step.start ?? position
                previousShape = step.shape
                elapsed += step.duration
                index += 1
                size = track.steps[index].size ?? size
                position = track.steps[index].start ?? position
            }
            let step = track.steps[index]
            guard var shape = step.shape else { return nil }
            let start = step.start ?? position
            let end = step.end ?? start
            let local = min(max(t - elapsed, 0), step.duration)
            let progress = step.duration > 0 ? local / step.duration : 1
            if let previousShape, transition > 0 {
                shape = previousShape.blended(to: shape, smoothstep(min(local / transition, 1)))
            }
            return shape.pose(
                at: HandPlacement(chirality: track.chirality, wrist: start + (end - start) * progress, size: size))
        }
    }

    /// The stream a clip renders to, with the synth parameters in the header.
    public static func stream(_ clip: Clip, noise: SynthNoise = .none, meta: [String: String] = [:]) -> LandmarkStream {
        var meta = meta
        meta["aspect"] = String(clip.aspect)
        meta["fps"] = String(clip.fps)
        return LandmarkStream(header: .init(source: "synth", meta: meta), frames: render(clip, noise: noise))
    }

    private static func perturb(_ pose: HandPose, noise: SynthNoise, random: inout SeededRandom) -> HandPose {
        guard noise.jitterPixels > 0 || noise.confidenceLoss > 0 || !noise.dimJoints.isEmpty else { return pose }
        var result = pose
        let sigma = noise.jitterPixels / 720
        for joint in Joint.allCases {
            guard var sample = pose[joint] else { continue }
            if sigma > 0 {
                sample.point = Point(
                    x: sample.point.x + random.gaussian() * sigma, y: sample.point.y + random.gaussian() * sigma)
            }
            if noise.confidenceLoss > 0, random.unit() < noise.confidenceLoss { sample.confidence = 0.1 }
            if noise.dimJoints.contains(joint) { sample.confidence = noise.dimConfidence }
            result[joint] = sample
        }
        return result
    }

    static func smoothstep(_ u: Double) -> Double { u * u * (3 - 2 * u) }

    private static func rounded(_ t: Double) -> Double { (t * 1_000_000).rounded() / 1_000_000 }
}
