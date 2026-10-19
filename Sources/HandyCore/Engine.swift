/// The gesture engine: a pure reducer over explicit states.
///
/// It reads no clock. Every input carries its own timestamp, so a recorded stream replays
/// to the same events every time. Every transition has a hysteresis band or a minimum dwell,
/// so a single noisy frame cannot flip a state.
public struct Engine: Sendable {
    public var settings: EngineSettings
    public private(set) var state: State

    public init(mode: Mode = .off, settings: EngineSettings = EngineSettings()) {
        self.settings = settings
        self.state = mode == .off ? .off : .watching
    }

    public var mode: Mode { state.mode }

    public mutating func handle(_ input: Input) -> [Event] {
        switch input {
        case .command(let command): handle(command)
        case .frame(let frame): handle(frame)
        }
    }

    /// What the HUD shows right now.
    public func status(at t: Double) -> Status {
        switch state {
        case .arming(let arming):
            Status(mode: mode, progress: min(max((t - arming.since) / settings.armHold, 0), 1))
        default:
            Status(mode: mode, progress: nil)
        }
    }

    private mutating func handle(_ command: Command) -> [Event] {
        switch command {
        case .start: mode == .off ? transition(to: .watching) : []
        case .stop: transition(to: .off)
        case .toggle: transition(to: mode == .off ? .watching : .off)
        }
    }

    private mutating func handle(_ frame: FrameFeatures) -> [Event] {
        switch state {
        case .off: []
        case .watching: watching(frame)
        case .arming(let current): arming(current, frame)
        case .engaged(let current): engaged(current, frame)
        }
    }

    private mutating func watching(_ frame: FrameFeatures) -> [Event] {
        guard let hand = pointerHand(in: frame), isOpenPalm(hand) else { return [] }
        return transition(to: .arming(Arming(hand: hand.id, since: frame.t, lastSeen: frame.t)))
    }

    private mutating func arming(_ current: Arming, _ frame: FrameFeatures) -> [Event] {
        var arming = current
        let t = frame.t
        guard let hand = frame.hands.first(where: { $0.id == arming.hand }) else {
            return t - arming.lastSeen >= settings.handLostGrace ? transition(to: .watching) : []
        }
        arming.lastSeen = t
        if isOpenPalm(hand) {
            arming.notOpenSince = nil
        } else {
            let since = arming.notOpenSince ?? t
            if t - since >= settings.armAbortDwell { return transition(to: .watching) }
            arming.notOpenSince = since
        }
        if arming.notOpenSince == nil, t - arming.since >= settings.armHold {
            var pointer = PointerTracker(settings: settings.pointer)
            pointer.reanchor(at: hand.palmCentroid, t: t)
            return transition(to: .engaged(Engaged(hand: hand.id, lastSeen: t, pointer: pointer)))
        }
        state = .arming(arming)
        return []
    }

    private mutating func engaged(_ current: Engaged, _ frame: FrameFeatures) -> [Event] {
        var engaged = current
        let t = frame.t
        guard let hand = frame.hands.first(where: { $0.id == engaged.hand }) else {
            return t - engaged.lastSeen >= settings.handLostGrace ? transition(to: .watching) : []
        }
        engaged.lastSeen = t
        var events: [Event] = []
        if isFist(hand) {
            let since = engaged.fistSince ?? t
            if t - since >= settings.fistDwell { return transition(to: .watching) }
            engaged.fistSince = since
            // Closing into a fist must not drag the cursor; hold it while the fist forms.
            engaged.pointer.reanchor(at: hand.palmCentroid, t: t)
        } else {
            engaged.fistSince = nil
            if let delta = engaged.pointer.delta(for: hand.palmCentroid, at: t) {
                events.append(.moveCursor(dx: delta.x, dy: delta.y))
            }
        }
        state = .engaged(engaged)
        return events
    }

    private func pointerHand(in frame: FrameFeatures) -> HandFeatures? {
        frame.hands.first { $0.chirality == settings.pointerHand }
    }

    /// Four fingers extended and the palm turned toward the camera. A resting or typing hand
    /// curls its fingers or turns its palm down, so it never qualifies.
    func isOpenPalm(_ hand: HandFeatures) -> Bool {
        [Finger.index, .middle, .ring, .little].allSatisfy(hand.isExtended)
            && hand.palmFacing >= settings.palmFacingMinimum
    }

    func isFist(_ hand: HandFeatures) -> Bool {
        ![Finger.index, .middle, .ring, .little].contains(where: hand.isExtended)
    }

    private mutating func transition(to next: State) -> [Event] {
        let previous = mode
        state = next
        return next.mode == previous ? [] : [.modeChanged(to: next.mode)]
    }
}

extension Engine {
    /// The externally visible state, for the HUD, the menu bar and handyctl.
    public enum Mode: String, Sendable, Codable, CaseIterable {
        case off
        case watching
        case arming
        case engaged
    }

    public enum State: Sendable, Equatable {
        case off
        case watching
        case arming(Arming)
        case engaged(Engaged)

        public var mode: Mode {
            switch self {
            case .off: .off
            case .watching: .watching
            case .arming: .arming
            case .engaged: .engaged
            }
        }
    }

    public struct Arming: Sendable, Equatable {
        public var hand: Int
        public var since: Double
        public var lastSeen: Double
        /// When the open palm last stopped qualifying, if it has not recovered.
        public var notOpenSince: Double?
    }

    public struct Engaged: Sendable, Equatable {
        public var hand: Int
        public var lastSeen: Double
        public var fistSince: Double?
        public var pointer: PointerTracker
    }

    /// User-level commands from the menu bar, the hotkey or handyctl.
    public enum Command: String, Sendable, Codable, CaseIterable {
        case start
        case stop
        case toggle
    }

    public enum Input: Sendable, Equatable {
        case command(Command)
        case frame(FrameFeatures)
    }

    public enum Event: Sendable, Equatable, Codable {
        case modeChanged(to: Mode)
        /// Relative cursor motion in points.
        case moveCursor(dx: Double, dy: Double)
    }

    public struct Status: Sendable, Equatable, Codable {
        public var mode: Mode
        /// Arming progress 0...1 for the progress ring; nil when not arming.
        public var progress: Double?

        public init(mode: Mode, progress: Double?) {
            self.mode = mode
            self.progress = progress
        }
    }
}

/// Every timing and threshold the engine uses. Defaults follow docs/spec.md.
public struct EngineSettings: Sendable, Hashable, Codable {
    public var pointerHand: Chirality = .right
    /// Open palm must be held this long to engage.
    public var armHold = 0.3
    /// Any finger curled this long aborts arming.
    public var armAbortDwell = 0.15
    /// A fist held this long disengages.
    public var fistDwell = 0.15
    /// The pointer hand may vanish this long (tracking dropouts) before Engaged ends.
    public var handLostGrace = 0.2
    /// `palmFacing` at or above this counts as facing the camera.
    public var palmFacingMinimum = 0.5
    public var pointer = PointerSettings()

    public init() {}
}
