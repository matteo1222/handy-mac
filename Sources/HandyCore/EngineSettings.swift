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
    public var oops = OopsSettings()
    public var palette = PaletteSettings()
    /// The open palm counts as held only below this palm speed, in frame heights per second.
    public var armMaxSpeed = 0.6
    /// Camera frame width over height; set from the live camera.
    public var frameAspect = 16.0 / 9

    public init() {}
}
