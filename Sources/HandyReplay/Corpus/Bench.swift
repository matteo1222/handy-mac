import Foundation
import HandyCore

/// Corpus-level quality numbers: false actions on no-gesture footage, cursor jitter and lag.
public struct BenchReport: Codable, Sendable, Equatable {
    public var noGestureHours: Double
    /// Actions fired during no-gesture footage, by kind.
    public var falseActions: [String: Int]
    public var falseActionsPerHour: Double
    /// Cursor RMS distance from its mean while an engaged hand holds still with 2 px joint noise, in points.
    public var jitterPoints: Double
    /// Delay between palm motion and cursor motion, in milliseconds, from cross-correlation.
    public var lagMilliseconds: Double
    /// Labelled gesture segments in the corpus whose expected event fired, by gesture.
    public var gestureRecall: [String: Double]
    /// Session processing time per frame (machine-dependent; reported, not gated).
    public var processingMicroseconds: Summary
    public var corpus: [String]

    public init(
        noGestureHours: Double, falseActions: [String: Int], falseActionsPerHour: Double, jitterPoints: Double,
        lagMilliseconds: Double, gestureRecall: [String: Double], processingMicroseconds: Summary, corpus: [String]
    ) {
        self.noGestureHours = noGestureHours
        self.falseActions = falseActions
        self.falseActionsPerHour = falseActionsPerHour
        self.jitterPoints = jitterPoints
        self.lagMilliseconds = lagMilliseconds
        self.gestureRecall = gestureRecall
        self.processingMicroseconds = processingMicroseconds
        self.corpus = corpus
    }
}

public enum Bench {
    /// What counts as an action reaching the user: engaging, clicking, dragging, scrolling, keys.
    public static func actionKind(_ event: Engine.Event) -> String? { event.actionKind }

    /// Counts false actions and timing over a stream of frames whose labels say what is no-gesture.
    public struct Accumulator {
        public private(set) var noGestureSeconds = 0.0
        public private(set) var falseActions: [String: Int] = [:]
        public private(set) var recallHits: [String: Int] = [:]
        public private(set) var recallTotals: [String: Int] = [:]
        public private(set) var timings: [Double] = []
        private let clock = ContinuousClock()

        public init() {}

        /// Runs one stream. Without labels the whole stream counts as no-gesture.
        public mutating func run(frames: (_ body: (LandmarkFrame) -> Void) -> Void, labels: [LandmarkStream.Label]) {
            var session = Session()
            var previousT: Double?
            var lastMode = Engine.Mode.watching
            var fired: [(t: Double, kind: String)] = []
            frames { frame in
                var events: [TimedEvent] = []
                let elapsed = clock.measure { events = session.process(frame) }
                timings.append(Double(elapsed.components.attoseconds) / 1e12 + Double(elapsed.components.seconds) * 1e6)
                let noGesture =
                    labels.isEmpty || labels.contains { $0.name == "none" && $0.start <= frame.t && frame.t < $0.end }
                if noGesture, let previousT { noGestureSeconds += frame.t - previousT }
                previousT = frame.t
                for event in events {
                    // Engaging counts once, when arming completes; returning to Engaged after a drag or scroll does not.
                    if case .modeChanged(let mode) = event.event {
                        let engaged = mode == .engaged && lastMode == .arming
                        lastMode = mode
                        if engaged {
                            if noGesture { falseActions["engage", default: 0] += 1 }
                            fired.append((frame.t, "engage"))
                        }
                        continue
                    }
                    guard let kind = Bench.actionKind(event.event) else { continue }
                    if noGesture { falseActions[kind, default: 0] += 1 }
                    fired.append((frame.t, kind))
                }
            }
            for label in labels where label.name != "none" {
                guard let expected = Bench.expectedKind(for: label.name) else { continue }
                recallTotals[label.name, default: 0] += 1
                if fired.contains(where: { $0.kind == expected && label.start <= $0.t && $0.t <= label.end + 0.5 }) {
                    recallHits[label.name, default: 0] += 1
                }
            }
        }
    }

    /// The action kind a gesture label should produce; nil for gestures that act on nothing
    /// (letting go, moving the pointer, the hard stop), which recall does not score.
    static func expectedKind(for label: String) -> String? {
        Gesture(rawValue: label).flatMap { expectedKinds[$0] ?? nil }
    }

    static let expectedKinds: [Gesture: String?] = [
        .engage: "engage", .disengage: nil, .moveCursor: nil, .hardStop: nil,
        .click: "click", .rightClick: "click", .doubleClick: "click", .drag: "drag", .scroll: "scroll",
        .thumbsUp: "oneShot.thumbsUp", .thumbsDown: "oneShot.thumbsDown", .dictation: "oneShot.shaka",
        .flickUp: "flick.up", .flickDown: "flick.down", .flickLeft: "flick.left", .flickRight: "flick.right",
        .swipeLeft: "swipe.left", .swipeRight: "swipe.right", .swipeUp: "swipe.up",
        .zoomIn: "zoom", .zoomOut: "zoom", .oops: "oops", .palette: "palette",
    ]

    /// Still-hand cursor jitter, as `handyctl bench-cursor` measures it at 2 px noise.
    public static func jitter() -> Double {
        let clip = Clip(hands: [
            Clip.HandTrack(chirality: .right, steps: [step(.openPalm, 6, at: Point(x: 0.9, y: 0.75))])
        ])
        let stream = Synthesizer.stream(clip, noise: SynthNoise(jitterPixels: 2, seed: 21))
        return CursorTrace.jitter(CursorTrace.run(stream))
    }

    /// Lag between palm and cursor: an engaged palm sweeps sinusoidally at 1 Hz; the lag is the shift
    /// that best aligns cursor velocity with palm velocity (parabolic sub-frame interpolation).
    public static func lag() -> Double {
        let fps = 30.0
        var steps = [step(.openPalm, 1, at: Point(x: 0.9, y: 0.75))]
        let segments = 40
        for i in 0..<segments * 4 {
            let phase = Double(i + 1) / Double(segments) * 2 * .pi
            steps.append(step(.openPalm, 1 / Double(segments), to: Point(x: 0.9 + 0.12 * sin(phase), y: 0.75)))
        }
        let clip = Clip(hands: [Clip.HandTrack(chirality: .right, steps: steps)], fps: fps)
        let frames = Synthesizer.render(clip)
        let trace = CursorTrace.run(LandmarkStream(header: .init(source: "synth"), frames: frames))
        let palm = frames.map {
            $0.hands.first.flatMap {
                Point.mean(
                    [$0[.wrist], $0[.indexMCP], $0[.middleMCP], $0[.ringMCP], $0[.littleMCP]].compactMap { $0?.point }
                ).x
            } ?? 0
        }
        let start = Int(1.5 * fps)
        let palmVelocity = zip(palm.dropFirst(start), palm.dropFirst(start + 1)).map { $1 - $0 }
        let cursor = trace.map(\.position.x)
        let cursorVelocity = zip(cursor.dropFirst(start), cursor.dropFirst(start + 1)).map { $1 - $0 }
        func correlation(_ shift: Int) -> Double {
            let count = palmVelocity.count - shift
            guard count > 0 else { return 0 }
            return (0..<count).reduce(0) { $0 + palmVelocity[$1] * cursorVelocity[$1 + shift] }
        }
        let scores = (0...10).map(correlation)
        guard let best = scores.indices.max(by: { scores[$0] < scores[$1] }) else { return 0 }
        var shift = Double(best)
        if best > 0, best < scores.count - 1 {
            let (a, b, c) = (scores[best - 1], scores[best], scores[best + 1])
            let denominator = a - 2 * b + c
            if denominator != 0 { shift += 0.5 * (a - c) / denominator }
        }
        return shift / fps * 1000
    }

    static func step(_ pose: PoseName, _ duration: Double, at point: Point? = nil, to end: Point? = nil) -> Clip.Step {
        Clip.Step(pose: pose, duration: duration, start: point, end: end, size: nil)
    }
}
