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

    static func make(status: Engine.Status, lastAction: String?, problem: String?) -> HUDState {
        if let problem {
            return HUDState(
                symbol: "exclamationmark.triangle.fill", title: problem, detail: nil, progress: nil, tone: .warning)
        }
        let detail = lastAction
        switch status.mode {
        case .off:
            return HUDState(symbol: "hand.raised.slash", title: "Off", detail: detail, progress: nil, tone: .quiet)
        case .watching:
            return HUDState(symbol: "eye", title: "Watching", detail: detail, progress: nil, tone: .quiet)
        case .arming:
            return HUDState(
                symbol: "hand.raised", title: "Hold open palm", detail: nil, progress: status.progress ?? 0,
                tone: .active)
        case .engaged:
            return HUDState(symbol: "hand.raised.fill", title: "Engaged", detail: detail, progress: nil, tone: .active)
        case .dragging:
            return HUDState(symbol: "hand.pinch.fill", title: "Dragging", detail: nil, progress: nil, tone: .active)
        }
    }
}
