/// Detects a scene too dark to track, from mean frame brightness (0...1), with hysteresis so the
/// warning neither flickers nor lingers.
public struct DarknessMonitor: Sendable, Equatable {
    /// Below this the scene counts as dark...
    public var darkBelow = 0.12
    /// ...for this long before the warning shows.
    public var dwell = 2.0
    /// The warning clears once brightness rises above this.
    public var clearAbove = 0.18

    public private(set) var isTooDark = false
    private var darkSince: Double?

    public init() {}

    public mutating func update(brightness: Double, at t: Double) {
        if isTooDark {
            if brightness > clearAbove {
                isTooDark = false
                darkSince = nil
            }
            return
        }
        guard brightness < darkBelow else {
            darkSince = nil
            return
        }
        let since = darkSince ?? t
        darkSince = since
        isTooDark = t - since >= dwell
    }
}
