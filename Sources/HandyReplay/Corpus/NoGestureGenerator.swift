import HandyCore

/// Synthesises "no gesture" footage: hands doing everyday things in front of the camera that must
/// never fire an action. Typing, resting, talking with the hands (including brief open palms and
/// quick pointing), near-pinches, glancing away and a second hand. Deterministic for a seed.
public enum NoGestureGenerator {
    public static func clip(seconds: Double, seed: UInt64) -> Clip {
        var random = SeededRandom(seed: seed)
        var main: [Clip.Step] = []
        var other: [Clip.Step] = []
        var face: [Clip.FaceStep] = []
        var elapsed = 0.0
        var wrist = Point(x: 0.9, y: 0.8)
        var previous: PoseName?
        var roll = 0.0
        var pitch = 0.0
        while elapsed < seconds {
            var (pose, duration) = everydayPose(&random)
            // Two open palms in a row would add up to a deliberate engage, which is not "no gesture".
            while pose == .openPalm, previous == .openPalm { (pose, duration) = everydayPose(&random) }
            // The wrist turns mostly when the pose changes; holding a pose keeps it within a few degrees.
            if pose == previous {
                roll += (random.unit() * 2 - 1) * 5
                pitch = min(max(pitch + (random.unit() * 2 - 1) * 5, 0), 40)
            } else {
                roll = (random.unit() * 2 - 1) * 30
                pitch = random.unit() * 40
            }
            previous = pose
            let target = Point(
                x: min(max(wrist.x + (random.unit() * 2 - 1) * 0.35, 0.3), 1.5),
                y: min(max(wrist.y + (random.unit() * 2 - 1) * 0.2, 0.55), 0.95))
            main.append(
                Clip.Step(
                    pose: pose, duration: duration, start: wrist, end: target, size: 0.1 + random.unit() * 0.07,
                    roll: roll, pitch: pitch))
            wrist = target
            elapsed += duration
        }
        var otherElapsed = 0.0
        while otherElapsed < seconds {
            let duration = 1 + random.unit() * 6
            let present = random.unit() < 0.35
            let pose: PoseName? = present ? (random.unit() < 0.5 ? .relaxed : .typing) : nil
            let at = Point(x: 0.3 + random.unit() * 0.4, y: 0.75 + random.unit() * 0.15)
            other.append(Clip.Step(pose: pose, duration: duration, start: at, end: at, size: 0.12))
            otherElapsed += duration
        }
        var faceElapsed = 0.0
        while faceElapsed < seconds {
            let duration = 1 + random.unit() * 8
            let away = random.unit() < 0.2
            let yaw = away ? (random.unit() < 0.5 ? -1 : 1) * (40 + random.unit() * 30) : (random.unit() * 2 - 1) * 20
            face.append(Clip.FaceStep(yaw: yaw, duration: duration))
            faceElapsed += duration
        }
        // Everyday pose changes take 150-400 ms; the synth's default 80 ms blend is for deliberate gestures.
        return Clip(
            hands: [Clip.HandTrack(chirality: .right, steps: main), Clip.HandTrack(chirality: .left, steps: other)],
            face: face, transition: 0.2)
    }

    /// A pose and how long it lasts. Open palms stay shorter than the 300 ms engage hold, as when
    /// gesturing while talking; holding one longer is an intent to engage, not "no gesture".
    static func everydayPose(_ random: inout SeededRandom) -> (PoseName, Double) {
        let roll = random.unit()
        var cumulative = 0.0
        for entry in everydayPoses {
            cumulative += entry.weight
            if roll < cumulative {
                let span = entry.seconds.upperBound - entry.seconds.lowerBound
                return (entry.pose, entry.seconds.lowerBound + random.unit() * span)
            }
        }
        return (.relaxed, 1)
    }

    struct EverydayPose {
        let pose: PoseName
        let weight: Double
        let seconds: ClosedRange<Double>
    }

    static let everydayPoses = [
        EverydayPose(pose: .relaxed, weight: 0.22, seconds: 0.5...3),
        EverydayPose(pose: .typing, weight: 0.22, seconds: 1...4),
        EverydayPose(pose: .fist, weight: 0.07, seconds: 0.3...1.5),
        EverydayPose(pose: .sideways, weight: 0.1, seconds: 0.3...2),
        EverydayPose(pose: .nearPinch, weight: 0.08, seconds: 0.2...1),
        EverydayPose(pose: .point, weight: 0.07, seconds: 0.3...1.2),
        EverydayPose(pose: .openPalm, weight: 0.09, seconds: 0.08...0.22),
        EverydayPose(pose: .twoFingers, weight: 0.05, seconds: 0.2...0.8),
        EverydayPose(pose: .pinch, weight: 0.05, seconds: 0.1...0.4),
        EverydayPose(pose: .pinchMiddle, weight: 0.05, seconds: 0.1...0.4),
    ]
}
