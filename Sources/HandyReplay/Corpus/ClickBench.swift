import HandyCore

/// A/B of the click gesture (thumb-index pinch vs index dip) on synthetic clips: recall on
/// deliberate clicks, recall when the fingertips are partly occluded (as from a front camera), and
/// false clicks per hour of engaged pointing with natural finger fidgets.
public enum ClickBench {
    public struct Result: Codable, Sendable, Equatable {
        public var gesture: ClickGesture
        public var clickRecall: Double
        public var occludedRecall: Double
        public var falseClicksPerHour: Double
        /// How close fidgets came to pressing: the smallest press signal seen minus the press threshold,
        /// on the pinch scale. Larger is safer.
        public var fidgetHeadroom: Double
        public var engagedHours: Double
    }

    public static func run(_ gesture: ClickGesture, clips: Int = 60, engagedMinutes: Double = 30) -> Result {
        var settings = EngineSettings()
        settings.click.gesture = gesture
        let clickPose: PoseName = gesture == .pinch ? .pinch : .indexDip
        var hits = 0
        var occludedHits = 0
        for seed in 0..<clips {
            var random = SeededRandom(seed: UInt64(1000 + seed))
            let clip = deliberateClick(clickPose, random: &random)
            if clicks(clip, settings, noise: SynthNoise(jitterPixels: 1.5, seed: UInt64(seed))) == 1 { hits += 1 }
            // The thumb tip hidden behind the index, as a front camera often sees a pinch.
            let dim = SynthNoise(jitterPixels: 1.5, dimJoints: [.thumbTip], dimConfidence: 0.4, seed: UInt64(seed))
            if clicks(clip, settings, noise: dim) == 1 { occludedHits += 1 }
        }
        var falseClicks = 0
        var seconds = 0.0
        var lowest = Double.infinity
        let chunk = 300.0
        for index in 0..<Int((engagedMinutes * 60 / chunk).rounded(.up)) {
            var random = SeededRandom(seed: UInt64(5000 + index))
            let clip = engagedPointing(seconds: chunk, random: &random)
            let noise = SynthNoise(jitterPixels: 2, seed: UInt64(index))
            falseClicks += clicks(clip, settings, noise: noise)
            lowest = min(lowest, lowestSignal(clip, settings, noise: noise))
            seconds += chunk
        }
        func round(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
        return Result(
            gesture: gesture, clickRecall: round(Double(hits) / Double(clips)),
            occludedRecall: round(Double(occludedHits) / Double(clips)),
            falseClicksPerHour: round(Double(falseClicks) / (seconds / 3600)),
            fidgetHeadroom: round(lowest - settings.click.press), engagedHours: round(seconds / 3600))
    }

    /// The smallest press signal (either finger) while engaged and not pressing.
    static func lowestSignal(_ clip: Clip, _ settings: EngineSettings, noise: SynthNoise) -> Double {
        var session = Session(engine: Engine(mode: .watching, settings: settings))
        var lowest = Double.infinity
        Synthesizer.forEachFrame(clip, noise: noise) { frame in
            _ = session.process(frame)
            guard session.engine.mode == .engaged, let hand = session.lastFeatures?.hands.first else { return }
            let signals = ClickSignals(hand, settings: settings.click)
            lowest = min(lowest, signals.index ?? .infinity, signals.middle ?? .infinity)
        }
        return lowest
    }

    /// Clicks and drags (both are a press reaching the OS) the clip produces.
    static func clicks(_ clip: Clip, _ settings: EngineSettings, noise: SynthNoise) -> Int {
        var session = Session(engine: Engine(mode: .watching, settings: settings))
        var count = 0
        Synthesizer.forEachFrame(clip, noise: noise) { frame in
            for event in session.process(frame) {
                switch event.event {
                case .click, .dragBegan: count += 1
                default: break
                }
            }
        }
        return count
    }

    /// Engage, aim, click once, carry on.
    static func deliberateClick(_ pose: PoseName, random: inout SeededRandom) -> Clip {
        let size = 0.1 + random.unit() * 0.07
        let start = Point(x: 0.6 + random.unit() * 0.6, y: 0.65 + random.unit() * 0.2)
        let aim = Point(x: start.x + (random.unit() - 0.5) * 0.2, y: start.y + (random.unit() - 0.5) * 0.1)
        let roll = (random.unit() * 2 - 1) * 20
        func step(_ pose: PoseName, _ duration: Double, _ at: Point? = nil, _ to: Point? = nil) -> Clip.Step {
            Clip.Step(pose: pose, duration: duration, start: at, end: to, size: size, roll: roll)
        }
        let steps = [
            step(.openPalm, 0.7, start), step(.openPalm, 0.4, nil, aim),
            step(pose, 0.1 + random.unit() * 0.08), step(.openPalm, 0.5),
        ]
        return Clip(hands: [Clip.HandTrack(chirality: .right, steps: steps)])
    }

    /// Engaged pointing with fidgets: fingers flex a little, the thumb drifts toward the index,
    /// the hand wanders. None of it is a click.
    static func engagedPointing(seconds: Double, random: inout SeededRandom) -> Clip {
        var steps = [Clip.Step(pose: .openPalm, duration: 0.7, start: Point(x: 0.9, y: 0.75), end: nil, size: 0.14)]
        var elapsed = 0.7
        var wrist = Point(x: 0.9, y: 0.75)
        while elapsed < seconds {
            let duration = 0.3 + random.unit() * 1.5
            let target = Point(
                x: min(max(wrist.x + (random.unit() - 0.5) * 0.3, 0.4), 1.4),
                y: min(max(wrist.y + (random.unit() - 0.5) * 0.15, 0.6), 0.9))
            let fidget = random.unit()
            let pose: PoseName = fidget < 0.7 ? .openPalm : (fidget < 0.85 ? .relaxedOpen : .nearPinch)
            steps.append(Clip.Step(pose: pose, duration: duration, start: wrist, end: target, size: 0.14))
            wrist = target
            elapsed += duration
        }
        return Clip(hands: [Clip.HandTrack(chirality: .right, steps: steps)], transition: 0.15)
    }
}
