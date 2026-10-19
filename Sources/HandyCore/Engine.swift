/// The gesture engine: a pure reducer over explicit states.
///
/// It reads no clock. Every input carries its own timestamp, so a recorded stream replays
/// to the same events every time. Every transition has a hysteresis band or a minimum dwell,
/// so a single noisy frame cannot flip a state.
public struct Engine: Sendable {
    public var settings: EngineSettings
    public private(set) var state: State
    private var attention: AttentionGate
    private var hardStop: HardStop
    private var oneShot: OneShotRecognizer
    private var flicks: FlickRecognizer
    private let classifier: PoseClassifier

    public init(
        mode: Mode = .off, settings: EngineSettings = EngineSettings(), classifier: PoseClassifier = .standard
    ) {
        self.settings = settings
        self.state = mode == .off ? .off : .watching
        self.classifier = classifier
        attention = AttentionGate(settings: settings.attention)
        hardStop = HardStop(settings: settings.hardStop)
        oneShot = OneShotRecognizer(settings: settings.oneShot)
        flicks = FlickRecognizer(settings: settings.flick)
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
        if case .watching = state, let hold = oneShot.progress(at: t) {
            return Status(mode: mode, progress: hold.fraction, oneShot: hold.pose)
        }
        return switch state {
        case .arming(let arming):
            Status(mode: mode, progress: min(max((t - arming.since) / settings.armHold, 0), 1))
        case .engaged(let engaged):
            Status(mode: mode, progress: nil, pinch: engaged.closeness)
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
        guard state != .off else { return [] }
        attention.observe(frame.face, at: frame.t)
        if hardStop.update(frame) { return releaseHeld(in: state) + transition(to: .off) }
        switch state {
        case .off: return []
        case .watching: return watching(frame)
        case .arming(let current):
            return attention.allowsEngaging(at: frame.t) ? arming(current, frame) : transition(to: .watching)
        case .engaged(let current):
            return attention.hasLookedAway(at: frame.t)
                ? releaseHeld(in: state) + transition(to: .watching) : engaged(current, frame)
        }
    }

    /// Ends any drag or scroll in progress, so nothing is left held down when a guard fires.
    private func releaseHeld(in state: State) -> [Event] {
        guard case .engaged(var engaged) = state else { return [] }
        return engaged.clicks.cancel() + engaged.scroll.cancel()
    }

    private mutating func watching(_ frame: FrameFeatures) -> [Event] {
        guard attention.allowsEngaging(at: frame.t) else {
            oneShot.reset()
            flicks.reset()
            return []
        }
        if let hand = pointerHand(in: frame), isOpenPalm(hand) {
            oneShot.reset()
            flicks.reset()
            return transition(to: .arming(Arming(hand: hand.id, since: frame.t, lastSeen: frame.t)))
        }
        // One-shots and flicks run only while not engaged, so a pointing hand never fires a shortcut.
        if let direction = flicks.update(pointerHand(in: frame), at: frame.t) {
            oneShot.reset()
            return [.flick(direction)]
        }
        let reading = (pointerHand(in: frame) ?? frame.hands.first).flatMap(classifier.read)
        return oneShot.update(reading, at: frame.t).map { [.oneShot($0)] } ?? []
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
            return transition(
                to: .engaged(
                    Engaged(
                        hand: hand.id, lastSeen: t, pointer: pointer, clicks: ClickRecognizer(settings: settings.click),
                        scroll: ScrollRecognizer(settings: settings.scroll))))
        }
        state = .arming(arming)
        return []
    }

    private mutating func engaged(_ current: Engaged, _ frame: FrameFeatures) -> [Event] {
        var engaged = current
        let t = frame.t
        guard let hand = frame.hands.first(where: { $0.id == engaged.hand }) else {
            guard t - engaged.lastSeen >= settings.handLostGrace else { return [] }
            return engaged.clicks.cancel() + engaged.scroll.cancel() + transition(to: .watching)
        }
        engaged.lastSeen = t
        var events: [Event] = []
        if isFist(hand), case .idle = engaged.clicks.phase {
            events += engaged.scroll.cancel()
            let since = engaged.fistSince ?? t
            if t - since >= settings.fistDwell { return events + transition(to: .watching) }
            engaged.fistSince = since
            // Closing into a fist must not drag the cursor; hold it while the fist forms.
            engaged.pointer.reanchor(at: hand.palmCentroid, t: t)
        } else {
            engaged.fistSince = nil
            events = pointer(&engaged, hand, at: t)
        }
        engaged.closeness = engaged.clicks.closeness(pinchIndex: hand.pinchIndex, pinchMiddle: hand.pinchMiddle)
        let previousMode = current.pointerMode
        state = .engaged(engaged)
        if engaged.pointerMode != previousMode { events.append(.modeChanged(to: mode)) }
        return events
    }

    /// Scroll gets first claim on the hand's motion; whatever it does not own goes to pointing and clicking.
    private func pointer(_ engaged: inout Engaged, _ hand: HandFeatures, at t: Double) -> [Event] {
        let step = engaged.pointer.step(for: hand.palmCentroid, at: t)
        var events: [Event] = []
        if case .idle = engaged.clicks.phase {
            let scrollPose = isScrollPose(hand)
            events = engaged.scroll.update(
                isScrollPose: scrollPose, motion: step.motion, cursorMoved: step.cursor != nil && !scrollPose, at: t)
            if engaged.scroll.ownsMotion { return events }
        }
        return events
            + engaged.clicks.update(
                pinchIndex: hand.pinchIndex, pinchMiddle: hand.pinchMiddle, delta: step.cursor,
                palm: hand.palmCentroid * settings.pointer.slowGain, at: t, reach: hand.reach)
    }

    /// Index and middle up, ring and little curled.
    func isScrollPose(_ hand: HandFeatures) -> Bool {
        hand.isExtended(.index) && hand.isExtended(.middle) && !hand.isExtended(.ring) && !hand.isExtended(.little)
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
        if next != .watching {
            oneShot.reset()
            flicks.reset()
        }
        if next == .watching, [.engaged, .dragging, .scrolling].contains(previous) { oneShot.blockUntilRelease() }
        if next == .off {
            attention = AttentionGate(settings: settings.attention)
            hardStop = HardStop(settings: settings.hardStop)
        }
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
        case dragging
        case scrolling
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
            case .engaged(let engaged): engaged.pointerMode
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
        public var clicks: ClickRecognizer
        /// How closed the pinch is, 0...1, for the cursor ring.
        public var closeness: Double?

        public var scroll: ScrollRecognizer

        /// Engaged, dragging or scrolling, for the HUD.
        public var pointerMode: Mode {
            if case .dragging = clicks.phase { return .dragging }
            return scroll.isScrolling ? .scrolling : .engaged
        }
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
        /// A press and release; `count` is 2 for a double click.
        case click(button: MouseButton, count: Int)
        case dragBegan(button: MouseButton)
        /// Relative drag motion in points.
        case dragMoved(dx: Double, dy: Double)
        case dragEnded(button: MouseButton)
        /// Content travel in points (content follows the hand), with trackpad phases.
        case scroll(dx: Double, dy: Double, phase: ScrollPhase)
        /// A static pose held to completion while not engaged.
        case oneShot(PoseClass)
        /// An index-finger flick while not engaged.
        case flick(Direction)
    }

    public struct Status: Sendable, Equatable, Codable {
        public var mode: Mode
        /// Arming progress 0...1 for the progress ring; nil when not arming.
        public var progress: Double?
        /// Pinch closeness 0...1 for the cursor ring; nil when not engaged or unknown.
        public var pinch: Double?
        /// The one-shot pose being held, whose hold `progress` measures.
        public var oneShot: PoseClass?

        public init(mode: Mode, progress: Double?, pinch: Double? = nil, oneShot: PoseClass? = nil) {
            self.mode = mode
            self.progress = progress
            self.pinch = pinch
            self.oneShot = oneShot
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
    public var click = ClickSettings()
    public var scroll = ScrollSettings()
    public var attention = AttentionSettings()
    public var hardStop = HardStopSettings()
    public var oneShot = OneShotSettings()
    public var flick = FlickSettings()

    public init() {}
}
