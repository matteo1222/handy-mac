import HandyCore

/// Who and where a corpus recording was made, stored in the stream header. Numbers and labels only.
public struct CorpusConditions: Sendable, Hashable, Codable {
    public enum Lighting: String, Sendable, Codable, CaseIterable {
        case bright, office, dim, backlit
    }

    public enum Distance: String, Sendable, Codable, CaseIterable {
        case near = "0.5m"
        case middle = "1.5m"
        case far = "3m"
    }

    public var participant: String
    public var lighting: Lighting
    public var distance: Distance
    /// Optional Fitzpatrick type I–VI, self-reported, to check coverage across skin tones.
    public var skinTone: String?
    public var background: String?

    public init(
        participant: String, lighting: Lighting, distance: Distance, skinTone: String? = nil, background: String? = nil
    ) {
        self.participant = participant
        self.lighting = lighting
        self.distance = distance
        self.skinTone = skinTone
        self.background = background
    }

    public var meta: [String: String] {
        var meta = ["participant": participant, "lighting": lighting.rawValue, "distance": distance.rawValue]
        meta["skinTone"] = skinTone
        meta["background"] = background
        return meta
    }

    /// A conditions grid cell, for filenames: p01-dim-1.5m.
    public var slug: String { "\(participant)-\(lighting.rawValue)-\(distance.rawValue)" }
}

/// One thing the participant is asked to do for a while; `label` becomes the clip's label.
public struct CorpusPrompt: Sendable, Hashable, Codable {
    /// A `Gesture` raw value, or `none` for footage that must fire nothing.
    public var label: String
    public var instruction: String
    public var seconds: Double

    public init(label: String, instruction: String, seconds: Double) {
        self.label = label
        self.instruction = instruction
        self.seconds = seconds
    }

    /// The standard protocol: every default gesture a few times, then everyday no-gesture activity.
    /// About 9 minutes per lighting and distance, 3 m 40 s of it no-gesture: a full 4 × 3 grid gives
    /// 44 minutes of no-gesture footage per participant, so three participants pass the 2 hours TASK-17 asks for.
    public static let standard: [CorpusPrompt] = {
        func gesture(_ gesture: Gesture, _ instruction: String, _ times: Int = 3, seconds: Double = 4) -> [CorpusPrompt]
        {
            (1...times).map { n in
                CorpusPrompt(
                    label: gesture.rawValue, instruction: "\(instruction), try \(n) of \(times)", seconds: seconds)
            }
        }
        var prompts: [CorpusPrompt] = []
        prompts += gesture(.engage, "Raise an open palm toward the camera and hold it")
        prompts += gesture(.disengage, "While engaged, make a fist")
        prompts += gesture(.moveCursor, "While engaged, move your open hand around", 1, seconds: 8)
        prompts += gesture(.click, "While engaged, pinch thumb and index once")
        prompts += gesture(.rightClick, "While engaged, pinch thumb and middle finger once")
        prompts += gesture(.doubleClick, "While engaged, pinch twice quickly")
        prompts += gesture(.drag, "While engaged, pinch, hold and move, then release")
        prompts += gesture(.scroll, "While engaged, raise two fingers and move up and down", 2, seconds: 6)
        prompts += gesture(.thumbsUp, "Not engaged: thumbs up and hold")
        prompts += gesture(.thumbsDown, "Not engaged: thumbs down and hold")
        for (flick, word) in [
            (Gesture.flickUp, "up"), (.flickDown, "down"), (.flickLeft, "left"), (.flickRight, "right"),
        ] {
            prompts += gesture(flick, "Not engaged: point, then flick your wrist \(word)", 2)
        }
        for (swipe, word) in [(Gesture.swipeLeft, "left"), (.swipeRight, "right"), (.swipeUp, "up")] {
            prompts += gesture(swipe, "Not engaged: swipe an open palm \(word)", 2)
        }
        prompts += gesture(.zoomIn, "While engaged, pinch with both hands and spread them", 2, seconds: 5)
        prompts += gesture(.zoomOut, "While engaged, pinch with both hands and bring them together", 2, seconds: 5)
        prompts += gesture(.dictation, "Not engaged: shaka 🤙 and hold", 2)
        prompts += gesture(.oops, "Not engaged: point and wag your finger", 2)
        prompts += gesture(.palette, "While engaged, pinch-hold with your other hand, then move up", 2, seconds: 5)
        prompts += gesture(.hardStop, "Cross both hands and hold", 2)
        prompts += [
            CorpusPrompt(label: "none", instruction: "Type on your keyboard as you normally would", seconds: 60),
            CorpusPrompt(label: "none", instruction: "Talk about your day, gesturing with your hands", seconds: 60),
            CorpusPrompt(label: "none", instruction: "Drink from a cup or bottle, rest, look around", seconds: 40),
            CorpusPrompt(label: "none", instruction: "Sit as you would on a video call", seconds: 60),
        ]
        return prompts
    }()
}

/// Runs a protocol against frame timestamps and turns it into labels. Pure, so it is tested.
public struct CorpusSession: Sendable {
    public let prompts: [CorpusPrompt]
    /// Seconds between prompts to read the next instruction; not labelled.
    public var gap: Double
    private var start: Double?

    public init(prompts: [CorpusPrompt] = CorpusPrompt.standard, gap: Double = 2) {
        self.prompts = prompts
        self.gap = gap
    }

    public enum Phase: Sendable, Equatable {
        case reading(next: Int, remaining: Double)
        case doing(index: Int, remaining: Double)
        case finished
    }

    public mutating func phase(at t: Double) -> Phase {
        let start = self.start ?? t
        self.start = start
        var elapsed = t - start
        for (index, prompt) in prompts.enumerated() {
            if elapsed < gap { return .reading(next: index, remaining: gap - elapsed) }
            elapsed -= gap
            if elapsed < prompt.seconds { return .doing(index: index, remaining: prompt.seconds - elapsed) }
            elapsed -= prompt.seconds
        }
        return .finished
    }

    /// Labels for every prompt, in stream time relative to the session start.
    public var labels: [LandmarkStream.Label] {
        var t = 0.0
        return prompts.map { prompt in
            t += gap
            defer { t += prompt.seconds }
            return LandmarkStream.Label(start: t, end: t + prompt.seconds, name: prompt.label)
        }
    }

    public var totalSeconds: Double { prompts.reduce(0) { $0 + gap + $1.seconds } }
}
