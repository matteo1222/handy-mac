import HandyCore

/// Everything the HUD pill shows. Built from engine status, the last fired action and any
/// camera problem, so the view stays render-only.
struct HUDState: Equatable {
    enum Tone: Equatable {
        case quiet
        case active
        case warning
    }

    var symbol: String
    var title: String
    var detail: String?
    /// 0...1 progress ring around the symbol (arming, one-shot hold), or nil.
    var progress: Double?
    var tone: Tone

    /// `binding` names what the pose in progress will do, e.g. "Return".
    static func make(
        status: Engine.Status, lastAction: String?, problem: String?, binding: String? = nil
    ) -> HUDState {
        if let problem {
            return HUDState(
                symbol: "exclamationmark.triangle.fill", title: problem, detail: nil, progress: nil, tone: .warning)
        }
        let detail = lastAction
        switch status.mode {
        case .off:
            return HUDState(symbol: "hand.raised.slash", title: "Off", detail: detail, progress: nil, tone: .quiet)
        case .watching:
            if let pose = status.oneShot, let progress = status.progress {
                return HUDState(
                    symbol: pose.symbol, title: pose.title, detail: binding, progress: progress, tone: .active)
            }
            return HUDState(symbol: "eye", title: "Watching", detail: detail, progress: nil, tone: .quiet)
        case .arming:
            return HUDState(
                symbol: "hand.raised", title: "Hold open palm", detail: nil, progress: status.progress ?? 0,
                tone: .active)
        case .engaged:
            return HUDState(symbol: "hand.raised.fill", title: "Engaged", detail: detail, progress: nil, tone: .active)
        case .dragging:
            return HUDState(symbol: "hand.pinch.fill", title: "Dragging", detail: nil, progress: nil, tone: .active)
        case .scrolling:
            return HUDState(
                symbol: "arrow.up.and.down.circle", title: "Scrolling", detail: nil, progress: nil, tone: .active)
        }
    }
}

extension PoseClass {
    var title: String {
        switch self {
        case .none: "No gesture"
        case .thumbsUp: "Thumbs up"
        case .thumbsDown: "Thumbs down"
        case .shaka: "Shaka"
        }
    }

    var symbol: String {
        switch self {
        case .none: "hand.raised"
        case .thumbsUp: "hand.thumbsup.fill"
        case .thumbsDown: "hand.thumbsdown.fill"
        case .shaka: "hand.wave.fill"
        }
    }
}
