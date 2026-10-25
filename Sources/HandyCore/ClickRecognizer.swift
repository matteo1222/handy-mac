public enum MouseButton: String, Sendable, Codable, CaseIterable {
    case left
    case right
}

/// Which finger motion clicks: the thumb-index pinch (Vision Pro style) or the index dip (Pawvis style).
public enum ClickGesture: String, Sendable, Hashable, Codable, CaseIterable {
    case pinch
    case indexDip
}

public struct ClickSettings: Sendable, Hashable, Codable {
    public var gesture = ClickGesture.pinch
    /// Index-dip mode: the finger's reach (hand scales) below which it presses, and above which it releases.
    public var dipPress = 0.35
    public var dipRelease = 0.55
    /// Fingertips below this confidence never press (matches FeatureExtractor's pinch rule).
    public var minTipConfidence = 0.5

    /// Pinch distance (/ hand scale) below which a pinch presses.
    public var press = 0.25
    /// Pinch distance above which it releases. The gap is the hysteresis band.
    public var release = 0.40
    /// Pinch distance at which the cursor ring starts to tighten.
    public var previewStart = 0.6
    /// A release within this long, and under `dragDistance` of motion, is a click. Real pinches held
    /// 0.3 to 0.5 s; at 0.25 s they all became drags.
    public var clickMaxDuration = 0.6
    /// Points of hand motion during a press that start a drag. A held real pinch shifts the tracked
    /// palm 5 to 22 points as the fingers fold; a deliberate drag moves hundreds.
    public var dragDistance = 30.0
    /// A second press within this long after a click, and within `doubleClickDistance`, counts up.
    public var doubleClickInterval = 0.35
    public var doubleClickDistance = 12.0
    /// A thumb-index pinch whose middle fingertip is also this close to the thumb (hand scales, any
    /// confidence) is a right click. From a front camera the thumb hides the middle tip in a
    /// thumb-middle pinch, so the tracker reports the index touching the thumb, the middle tip close
    /// but unsure. A real left click keeps the middle tip far (0.6 or more) and plainly visible.
    public var middleNear = 0.35
    /// A pinch only starts when its finger reaches out at least this far (`HandFeatures.reach`).
    /// A thumb resting on a finger curled into the palm is not a pinch.
    public var minFingerReach = 0.25

    public init() {}
}

/// Left/right click, double click and drag from pinch distances and cursor motion.
///
/// The cursor freezes at pinch onset: motion during a press is held back, so a click lands where
/// the user aimed, and only becomes a drag past `dragDistance` or `clickMaxDuration`. After a
/// click the cursor also stays put for the double-click interval unless the hand clearly moves.
public struct ClickRecognizer: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case idle
        case pressing(Press)
        case dragging(MouseButton, Finger)
    }

    public struct Press: Sendable, Equatable {
        public var button: MouseButton
        /// The finger whose pinch started the press, and whose opening releases it.
        public var finger: Finger
        public var since: Double
        /// Raw palm position at press, in points.
        public var origin: Point
        /// Filtered cursor motion held back since press, released into the drag if one starts.
        public var motion: Point
        public var count: Int
    }

    struct LastClick: Sendable, Equatable {
        var button: MouseButton
        var releasedAt: Double
        var motion: Point
        var count: Int
    }

    public var settings: ClickSettings
    public private(set) var phase: Phase = .idle
    private var lastClick: LastClick?

    public init(settings: ClickSettings) {
        self.settings = settings
    }

    /// How closed the pinch is, 0 (open) to 1 (pressing), for the cursor ring.
    public func closeness(pinchIndex: Double?, pinchMiddle: Double?) -> Double? {
        guard let pinch = [pinchIndex, pinchMiddle].compactMap({ $0 }).min() else { return nil }
        let span = settings.previewStart - settings.press
        return min(max((settings.previewStart - pinch) / span, 0), 1)
    }

    /// Advances one frame. `delta` is this frame's cursor motion from the pointer tracker; the
    /// returned events say whether and how it reaches the OS. `palm` is the raw (unfiltered) palm
    /// position in points: click-versus-drag is judged on real hand travel, not on filter lag
    /// catching up after the hand stops to aim.
    public mutating func update(
        pinchIndex: Double?, pinchMiddle: Double?, delta: Point?, palm: Point, at t: Double,
        reach: FingerValues? = nil, middleNear: Double? = .infinity
    ) -> [Engine.Event] {
        let motion = delta ?? .zero
        switch phase {
        case .idle:
            let index = reach.map { $0.index >= settings.minFingerReach } ?? true ? pinchIndex : nil
            let middle = reach.map { $0.middle >= settings.minFingerReach } ?? true ? pinchMiddle : nil
            if let (button, finger) = pressed(pinchIndex: index, pinchMiddle: middle, middleNear: middleNear) {
                phase = .pressing(
                    Press(
                        button: button, finger: finger, since: t, origin: palm, motion: .zero,
                        count: nextCount(for: button, at: t)))
                return []
            }
            return idleMotion(motion, at: t)

        case .pressing(var press):
            if isReleased(press.finger, pinchIndex: pinchIndex, pinchMiddle: pinchMiddle) {
                phase = .idle
                lastClick = LastClick(button: press.button, releasedAt: t, motion: .zero, count: press.count)
                return [.click(button: press.button, count: press.count)]
            }
            press.motion += motion
            let travel = palm.distance(to: press.origin)
            if travel > settings.dragDistance || t - press.since > settings.clickMaxDuration {
                phase = .dragging(press.button, press.finger)
                lastClick = nil
                let held = press.motion
                return [.dragBegan(button: press.button)] + (held == .zero ? [] : [.dragMoved(dx: held.x, dy: held.y)])
            }
            phase = .pressing(press)
            return []

        case .dragging(let button, let finger):
            if isReleased(finger, pinchIndex: pinchIndex, pinchMiddle: pinchMiddle) {
                phase = .idle
                return [.dragEnded(button: button)]
            }
            return delta.map { [.dragMoved(dx: $0.x, dy: $0.y)] } ?? []
        }
    }

    /// Drops a press without clicking (a two-hand zoom took over); ends a drag cleanly.
    public mutating func abandon() -> [Engine.Event] {
        defer {
            phase = .idle
            lastClick = nil
        }
        if case .dragging(let button, _) = phase { return [.dragEnded(button: button)] }
        return []
    }

    /// Ends any drag, for disengaging mid-gesture.
    public mutating func cancel() -> [Engine.Event] {
        defer {
            phase = .idle
            lastClick = nil
        }
        if case .dragging(let button, _) = phase { return [.dragEnded(button: button)] }
        return []
    }

    private mutating func idleMotion(_ motion: Point, at t: Double) -> [Engine.Event] {
        if var last = lastClick, t - last.releasedAt <= settings.doubleClickInterval {
            last.motion += motion
            if last.motion.length <= settings.doubleClickDistance {
                lastClick = last
                return []
            }
            // Clearly moving on: release the held-back motion so the cursor catches up.
            lastClick = nil
            return [.moveCursor(dx: last.motion.x, dy: last.motion.y)]
        }
        lastClick = nil
        return motion == .zero ? [] : [.moveCursor(dx: motion.x, dy: motion.y)]
    }

    private func nextCount(for button: MouseButton, at t: Double) -> Int {
        guard let last = lastClick, last.button == button, t - last.releasedAt <= settings.doubleClickInterval,
            last.motion.length <= settings.doubleClickDistance
        else { return 1 }
        return min(last.count + 1, 3)
    }

    /// The button and the finger that pressed it. A thumb-index pinch is a right click when the middle
    /// tip is near the thumb too, or hidden (nil: the thumb covers it); `middleNear` is infinite when
    /// there is no such reading to use (index-dip mode).
    private func pressed(pinchIndex: Double?, pinchMiddle: Double?, middleNear: Double?) -> (MouseButton, Finger)? {
        if let index = pinchIndex, index < settings.press {
            let right = middleNear.map { $0 < settings.middleNear } ?? true
            return (right ? .right : .left, .index)
        }
        if let middle = pinchMiddle, middle < settings.press { return (.right, .middle) }
        return nil
    }

    /// Released only on a confident reading above the band; a missing reading holds the press.
    private func isReleased(_ finger: Finger, pinchIndex: Double?, pinchMiddle: Double?) -> Bool {
        let pinch = finger == .index ? pinchIndex : pinchMiddle
        return pinch.map { $0 > settings.release } ?? false
    }
}

/// The press signals the click recognizer reads, on the pinch scale (press below `press`, release
/// above `release`). In index-dip mode a finger's reach is rescaled onto that scale, so one
/// recognizer serves both gestures.
public struct ClickSignals: Sendable, Equatable {
    public var index: Double?
    public var middle: Double?
    /// Finger reach for gating pinches; nil in dip mode, where the reach is the signal itself.
    public var reach: FingerValues?
    /// The middle tip's distance from the thumb at any confidence (nil when the tracker lost it);
    /// infinite in dip mode, which tells the buttons apart by finger instead.
    public var middleNear: Double? = .infinity

    public init(_ hand: HandFeatures, settings: ClickSettings) {
        switch settings.gesture {
        case .pinch:
            index = hand.pinchIndex
            middle = hand.pinchMiddle
            reach = hand.reach
            middleNear = hand.middleNearThumb
        case .indexDip:
            // Map reach so dipPress lands on press and dipRelease on release. Like a pinch, a dip is never
            // read from a fingertip the model is unsure of.
            func rescale(_ finger: Finger) -> Double? {
                guard hand.jointConfidence[finger.tip.rawValue] >= settings.minTipConfidence else { return nil }
                let u = (hand.reach[finger] - settings.dipPress) / (settings.dipRelease - settings.dipPress)
                return settings.press + u * (settings.release - settings.press)
            }
            index = rescale(.index)
            middle = rescale(.middle)
            reach = nil
        }
    }
}
