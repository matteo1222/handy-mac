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
    private var swipes: SwipeRecognizer
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
        swipes = SwipeRecognizer(settings: settings.swipe)
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
        let palm = pointerHand(in: frame).flatMap { isOpenPalm($0) ? $0 : nil }
        if let direction = swipes.update(openPalm: palm, aspect: settings.frameAspect, at: frame.t) {
            return [.swipe(direction)]
        }
        if let hand = palm, !swipes.isQuiet(at: frame.t) {
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
        let open = isOpenPalm(hand)
        if let direction = swipes.update(openPalm: open ? hand : nil, aspect: settings.frameAspect, at: t) {
            return transition(to: .watching) + [.swipe(direction)]
        }
        // Engaging means holding the palm up; a hand moving fast is mid-swipe or passing by.
        if hand.velocity.length > settings.armMaxSpeed { arming.since = t }
        if open {
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
                        scroll: ScrollRecognizer(settings: settings.scroll),
                        zoom: ZoomRecognizer(settings: settings.zoom))))
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
            events = zoom(&engaged, hand, frame) ?? pointer(&engaged, hand, at: t)
        }
        engaged.closeness = engaged.clicks.closeness(pinchIndex: hand.pinchIndex, pinchMiddle: hand.pinchMiddle)
        let previousMode = current.pointerMode
        state = .engaged(engaged)
        if engaged.pointerMode != previousMode { events.append(.modeChanged(to: mode)) }
        return events
    }

    /// Two-hand pinch zoom takes over both hands while it runs; returns nil when not zooming.
    private func zoom(_ engaged: inout Engaged, _ hand: HandFeatures, _ frame: FrameFeatures) -> [Event]? {
        func pinch(_ hand: HandFeatures?) -> (pinched: Bool, at: Point)? {
            guard let hand, let thumb = hand[.thumbTip], let index = hand[.indexTip] else { return nil }
            let pinched =
                (hand.pinchIndex ?? 1) < settings.click.press && hand.reach.index >= settings.click.minFingerReach
            return (pinched, (thumb + index) / 2)
        }
        let other = frame.hands.first { $0.id != engaged.hand }
        let wasZooming = engaged.zoom.isZooming
        let steps = engaged.zoom.update(pointer: pinch(hand), other: pinch(other), at: frame.t)
        guard engaged.zoom.isZooming else { return wasZooming ? [] : nil }
        var events = wasZooming ? [] : engaged.clicks.abandon() + engaged.scroll.cancel()
        // The cursor stays where it was while zooming.
        engaged.pointer.reanchor(at: hand.palmCentroid, t: frame.t)
        events += steps.map { .zoom($0) }
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

    /// Clearly index and middle up, ring and little curled. The margins keep a relaxed hand, whose
    /// fingers curl a little more from index to little, from reading as the scroll pose.
    func isScrollPose(_ hand: HandFeatures) -> Bool {
        hand.reach.index > 0.6 && hand.reach.middle > 0.6 && hand.reach.ring < 0.2 && hand.reach.little < 0.2
    }

    private func pointerHand(in frame: FrameFeatures) -> HandFeatures? {
        frame.hands.first { $0.chirality == settings.pointerHand }
    }

    /// Four fingers extended, the palm turned toward the camera and the thumb clear of the index.
    /// A resting or typing hand curls its fingers or turns its palm down, and an "OK" sign or a
    /// half-pinch keeps the thumb on the index, so none of them qualify.
    func isOpenPalm(_ hand: HandFeatures) -> Bool {
        [Finger.index, .middle, .ring, .little].allSatisfy(hand.isExtended)
            && hand.palmFacing >= settings.palmFacingMinimum
            && (hand.pinchIndex.map { $0 > settings.click.previewStart } ?? true)
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
        if next != .watching, next.mode != .arming { swipes.reset() }
        if next == .watching, [.engaged, .dragging, .scrolling, .zooming].contains(previous) {
            oneShot.blockUntilRelease()
        }
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
        case zooming
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
        public var zoom: ZoomRecognizer

        /// Engaged, dragging, scrolling or zooming, for the HUD.
        public var pointerMode: Mode {
            if zoom.isZooming { return .zooming }
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
        /// An open-palm swipe while not engaged.
        case swipe(Direction)
        /// One step of two-hand pinch zoom.
        case zoom(ZoomDirection)
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
    public var swipe = SwipeSettings()
    public var zoom = ZoomSettings()
    /// The open palm counts as held only below this palm speed, in frame heights per second.
    public var armMaxSpeed = 0.6
    /// Camera frame width over height; set from the live camera.
    public var frameAspect = 16.0 / 9

    public init() {}
}
