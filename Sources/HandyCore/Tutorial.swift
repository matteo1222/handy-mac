/// The first-run tutorial: engage, move, click a big target, scroll a list, disengage. It advances
/// on engine events alone, so a replayed clip can walk it end to end.
public struct Tutorial: Sendable, Equatable {
    public enum Step: String, Sendable, Codable, CaseIterable {
        case welcome
        case cameraPermission
        case framing
        case engage
        case move
        case click
        case scroll
        case disengage
        case done

        public var next: Step? {
            let all = Step.allCases
            guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
            return all[index + 1]
        }
    }

    public private(set) var step: Step = .welcome
    /// Cursor travel in the move step, scroll travel in the scroll step, in points.
    public private(set) var travel = 0.0

    /// Points of cursor travel that complete the move step.
    public static let moveGoal = 600.0
    /// Points of scrolling that complete the scroll step.
    public static let scrollGoal = 400.0

    public init(step: Step = .welcome) {
        self.step = step
    }

    /// Steps the user completes with a button rather than a gesture.
    public mutating func continueFromButton() {
        guard [.welcome, .cameraPermission, .framing].contains(step) else { return }
        advance()
    }

    public var progress: Double? {
        switch step {
        case .move: min(travel / Self.moveGoal, 1)
        case .scroll: min(travel / Self.scrollGoal, 1)
        default: nil
        }
    }

    public mutating func handle(_ event: Engine.Event) {
        switch (step, event) {
        case (.engage, .modeChanged(.engaged)):
            advance()
        case (.move, .moveCursor(let dx, let dy)):
            travel += (dx * dx + dy * dy).squareRoot()
            if travel >= Self.moveGoal { advance() }
        case (.click, .click(.left, _)):
            advance()
        case (.scroll, .scroll(let dx, let dy, .changed)), (.scroll, .scroll(let dx, let dy, .momentum)):
            travel += (dx * dx + dy * dy).squareRoot()
            if travel >= Self.scrollGoal { advance() }
        case (.disengage, .modeChanged(.watching)), (.disengage, .modeChanged(.off)):
            advance()
        default:
            break
        }
    }

    private mutating func advance() {
        step = step.next ?? .done
        travel = 0
    }
}

/// Live advice for the framing check, from the current frame's hands and brightness.
public enum FramingAdvice: String, Sendable, Codable, CaseIterable {
    case raiseHand
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case comeCloser
    case moveBack
    case moreLight
    case good

    public var message: String {
        switch self {
        case .raiseHand: "Raise your hand into view"
        case .moveLeft: "Move your hand a little to the left"
        case .moveRight: "Move your hand a little to the right"
        case .moveUp: "Raise your hand a little"
        case .moveDown: "Lower your hand a little"
        case .comeCloser: "Come a little closer"
        case .moveBack: "Move back a little"
        case .moreLight: "Add more light"
        case .good: "Looks good"
        }
    }

    /// The most useful single piece of advice. `aspect` is frame width over height; positions are
    /// in the mirrored image, so the user's left is the image's left.
    public static func advise(_ frame: FrameFeatures, brightness: Double, aspect: Double) -> FramingAdvice {
        if brightness < 0.15 { return .moreLight }
        guard let hand = frame.hands.first else { return .raiseHand }
        let x = hand.palmCentroid.x / aspect
        let y = hand.palmCentroid.y
        if x < 0.15 { return .moveRight }
        if x > 0.85 { return .moveLeft }
        if y < 0.2 { return .moveDown }
        if y > 0.9 { return .moveUp }
        if hand.scale < 0.04 { return .comeCloser }
        if hand.scale > 0.3 { return .moveBack }
        return .good
    }
}

/// Per-user numbers learned during the tutorial. Numbers only, never images.
public struct Calibration: Sendable, Hashable, Codable {
    public static let version = 1

    public var version = Calibration.version
    /// Median hand scale (wrist to middle MCP) in frame heights.
    public var handSize: Double
    /// Pinch distance (/ hand scale) that presses, and the one that releases.
    public var pinchPress: Double
    public var pinchRelease: Double
    /// The palm-centroid box the user comfortably reached while engaged in the tutorial, in frame heights.
    public var reachBox: Rect

    public init(handSize: Double, pinchPress: Double, pinchRelease: Double, reachBox: Rect) {
        self.handSize = handSize
        self.pinchPress = pinchPress
        self.pinchRelease = pinchRelease
        self.reachBox = reachBox
    }

    /// Applies the learned thresholds to engine settings.
    public func apply(to settings: inout EngineSettings) {
        settings.click.press = pinchPress
        settings.click.release = pinchRelease
    }
}

/// Collects samples during the tutorial and turns them into a `Calibration`.
public struct CalibrationRecorder: Sendable, Equatable {
    private var scales: [Double] = []
    private var openPinches: [Double] = []
    private var closedPinches: [Double] = []
    private var minPalm: Point?
    private var maxPalm: Point?

    public init() {}

    /// Feed every frame while the tutorial runs. `step` says what the user is doing.
    public mutating func observe(_ frame: FrameFeatures, step: Tutorial.Step, mode: Engine.Mode) {
        guard let hand = frame.hands.first else { return }
        scales.append(hand.scale)
        if [Tutorial.Step.move, .click, .scroll].contains(step), mode != .watching, mode != .off {
            let palm = hand.palmCentroid
            minPalm = Point(x: min(minPalm?.x ?? palm.x, palm.x), y: min(minPalm?.y ?? palm.y, palm.y))
            maxPalm = Point(x: max(maxPalm?.x ?? palm.x, palm.x), y: max(maxPalm?.y ?? palm.y, palm.y))
        }
        guard let pinch = hand.pinchIndex else { return }
        if [Tutorial.Step.engage, .move].contains(step) { openPinches.append(pinch) }
        if step == .click { closedPinches.append(pinch) }
    }

    /// Nil until there is enough of each sample to trust.
    public func calibration() -> Calibration? {
        guard scales.count >= 30, openPinches.count >= 15, closedPinches.count >= 3, let minPalm, let maxPalm else {
            return nil
        }
        let open = Self.median(openPinches)
        let closed = closedPinches.min() ?? 0
        let span = max(open - closed, 0.1)
        let press = min(max(closed + span * 0.35, 0.15), 0.35)
        let release = max(min(closed + span * 0.6, 0.6), press + 0.1)
        return Calibration(
            handSize: Self.median(scales), pinchPress: press, pinchRelease: release,
            reachBox: Rect(x: minPalm.x, y: minPalm.y, width: maxPalm.x - minPalm.x, height: maxPalm.y - minPalm.y))
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }
}
