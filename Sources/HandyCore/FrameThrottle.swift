/// Decides which camera frames perception processes, from frame timestamps only.
///
/// While a hand has been seen in the last `idleAfter` seconds every frame is processed.
/// After that, frames are processed at most every `idleInterval` (10 fps) until a hand returns.
/// The face detector runs at most every `faceInterval` (5 fps).
public struct FrameThrottle: Sendable {
    public var idleAfter = 5.0
    public var idleInterval = 0.1
    public var faceInterval = 0.2

    private var lastHandSeen: Double?
    private var lastProcessed: Double?
    private var lastFace: Double?
    private var started: Double?

    public init() {}

    public func isIdle(at t: Double) -> Bool {
        let reference = lastHandSeen ?? started ?? t
        return t - reference >= idleAfter
    }

    public mutating func shouldProcess(at t: Double) -> Bool {
        if started == nil { started = t }
        if isIdle(at: t), let lastProcessed, t - lastProcessed < idleInterval - 1e-6 { return false }
        lastProcessed = t
        return true
    }

    public mutating func shouldDetectFace(at t: Double) -> Bool {
        if let lastFace, t - lastFace < faceInterval - 1e-6 { return false }
        lastFace = t
        return true
    }

    public mutating func record(handsSeen: Bool, at t: Double) {
        if handsSeen { lastHandSeen = t }
    }
}
