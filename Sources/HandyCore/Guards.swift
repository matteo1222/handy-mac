public struct AttentionSettings: Sendable, Hashable, Codable {
    public var enabled = true
    /// Engagement is allowed only while the face is turned within this many degrees of the camera.
    /// Users with a second display beside the camera may want it wider.
    public var maxYaw = 30.0
    /// Looking away this long while engaged returns to Watching.
    public var awayDwell = 0.3
    /// Without a face reading for this long, the gate stays open (the detector is not running).
    public var staleAfter = 1.0

    public init() {}
}

/// The attention gate: is the user facing the screen? Fed by 5 fps face readings.
public struct AttentionGate: Sendable, Equatable {
    public var settings: AttentionSettings
    private var lastReading: (t: Double, facing: Bool)?
    private var awaySince: Double?

    public init(settings: AttentionSettings) {
        self.settings = settings
    }

    public static func == (a: AttentionGate, b: AttentionGate) -> Bool {
        a.settings == b.settings && a.lastReading?.t == b.lastReading?.t
            && a.lastReading?.facing == b.lastReading?.facing
            && a.awaySince == b.awaySince
    }

    public mutating func observe(_ face: FaceSample?, at t: Double) {
        guard let face else { return }
        let facing = face.yaw.map { abs($0) <= settings.maxYaw } ?? false
        if facing {
            awaySince = nil
        } else if awaySince == nil {
            awaySince = t
        }
        lastReading = (t, facing)
    }

    /// May the user start engaging right now?
    public func allowsEngaging(at t: Double) -> Bool {
        guard settings.enabled, let lastReading, t - lastReading.t <= settings.staleAfter else { return true }
        return lastReading.facing
    }

    /// Has the user looked away long enough to drop an engagement?
    public func hasLookedAway(at t: Double) -> Bool {
        guard settings.enabled, let awaySince, let lastReading, t - lastReading.t <= settings.staleAfter else {
            return false
        }
        return t - awaySince >= settings.awayDwell
    }
}

public struct HardStopSettings: Sendable, Hashable, Codable {
    /// Crossed hands must hold this long.
    public var hold = 1.0
    /// How far past each other the wrists must be, in hand scales.
    public var crossMargin = 0.3

    public init() {}
}

/// Two crossed hands held for a second: the protective "stop tracking" gesture.
public struct HardStop: Sendable, Equatable {
    public var settings: HardStopSettings
    private var crossedSince: Double?

    public init(settings: HardStopSettings) {
        self.settings = settings
    }

    /// True on the frame the hold completes.
    public mutating func update(_ frame: FrameFeatures) -> Bool {
        guard isCrossed(frame) else {
            crossedSince = nil
            return false
        }
        let since = crossedSince ?? frame.t
        crossedSince = since
        return frame.t - since >= settings.hold
    }

    public func progress(at t: Double) -> Double? {
        crossedSince.map { min(max((t - $0) / settings.hold, 0), 1) }
    }

    /// In the mirrored image the left hand sits left of the right hand; crossed arms swap them.
    func isCrossed(_ frame: FrameFeatures) -> Bool {
        guard let left = frame.hands.first(where: { $0.chirality == .left }),
            let right = frame.hands.first(where: { $0.chirality == .right }),
            let leftWrist = left[.wrist], let rightWrist = right[.wrist]
        else { return false }
        let margin = settings.crossMargin * max(left.scale, right.scale)
        return leftWrist.x > rightWrist.x + margin
    }
}
