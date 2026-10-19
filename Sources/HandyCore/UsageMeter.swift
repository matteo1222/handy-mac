/// Counts-only usage, for measuring accidental actions per hour of active use. Never records what
/// was clicked or typed, only how many actions of each kind fired and for how long Handy was engaged.
public struct UsageStats: Sendable, Hashable, Codable {
    /// Seconds spent engaged (pointing, dragging, scrolling, zooming or in the palette).
    public var activeSeconds = 0.0
    /// Actions that reached macOS, by kind (see `Engine.Event.actionKind`).
    public var actions: [String: Int] = [:]
    /// Oops gestures: actions the user undid as accidental.
    public var oops = 0

    public init() {}

    public var activeHours: Double { activeSeconds / 3600 }

    /// Accidental actions per hour of active use; nil before any active time.
    public var accidentalPerHour: Double? {
        activeSeconds > 0 ? Double(oops) / activeHours : nil
    }

    public mutating func merge(_ other: UsageStats) {
        activeSeconds += other.activeSeconds
        oops += other.oops
        actions.merge(other.actions, uniquingKeysWith: +)
    }
}

/// Folds engine events into `UsageStats`, using frame timestamps for engaged time.
public struct UsageMeter: Sendable {
    public private(set) var stats = UsageStats()
    private var engaged = false
    private var lastT: Double?
    /// Gaps longer than this (the camera stopped, an inject) do not count as engaged time.
    public var maxGap = 1.0

    public init() {}

    public mutating func observe(_ event: Engine.Event) {
        if case .modeChanged(let mode) = event {
            engaged = [.engaged, .dragging, .scrolling, .zooming, .palette].contains(mode)
        }
        if event == .oops { stats.oops += 1 }
        if let kind = event.actionKind { stats.actions[kind, default: 0] += 1 }
    }

    /// Advances time by a frame, so engaged time accrues as it happens.
    public mutating func tick(at t: Double) {
        defer { lastT = t }
        guard engaged, let lastT, t > lastT, t - lastT <= maxGap else { return }
        stats.activeSeconds += t - lastT
    }

    /// Hands over the stats so far and starts counting afresh (for periodic saving).
    public mutating func drain() -> UsageStats {
        defer { stats = UsageStats() }
        return stats
    }
}

extension Engine.Event {
    /// The kind of action this event fires on the user's behalf, or nil when it acts on nothing.
    public var actionKind: String? {
        switch self {
        case .click: "click"
        case .dragBegan: "drag"
        case .scroll(_, _, .began): "scroll"
        case .oneShot(let pose): "oneShot.\(pose.rawValue)"
        case .flick(let direction): "flick.\(direction.rawValue)"
        case .swipe(let direction): "swipe.\(direction.rawValue)"
        case .zoom: "zoom"
        case .oops: "oops"
        case .palette(.fired): "palette"
        default: nil
        }
    }
}
