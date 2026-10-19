/// The other hand (not the pointer hand) showing an open palm for two seconds asks for the
/// cheat sheet; lowering it puts the sheet away. The pointer hand never triggers it, so engaging
/// is unaffected.
public struct CheatSheetRecognizer: Sendable, Equatable {
    public var hold = 2.0
    public var release = 0.3
    public private(set) var isShowing = false
    private var openSince: Double?
    private var closedSince: Double?

    public init() {}

    /// Puts the sheet away now, for turning off.
    public mutating func hide() -> [Engine.Event] {
        openSince = nil
        closedSince = nil
        guard isShowing else { return [] }
        isShowing = false
        return [.cheatSheet(shown: false)]
    }

    public mutating func update(otherHandOpen: Bool, at t: Double) -> [Engine.Event] {
        if otherHandOpen {
            closedSince = nil
            let since = openSince ?? t
            openSince = since
            guard !isShowing, t - since >= hold else { return [] }
            isShowing = true
            return [.cheatSheet(shown: true)]
        }
        openSince = nil
        guard isShowing else { return [] }
        let since = closedSince ?? t
        closedSince = since
        guard t - since >= release else { return [] }
        isShowing = false
        closedSince = nil
        return [.cheatSheet(shown: false)]
    }
}
