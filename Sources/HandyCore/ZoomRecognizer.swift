public enum ZoomDirection: String, Sendable, Codable, CaseIterable {
    case zoomIn
    case zoomOut
}

public struct ZoomSettings: Sendable, Hashable, Codable {
    /// Both hands must start pinching within this long of each other.
    public var together = 0.3
    /// One zoom step per this change in distance between the pinches (0.15 = 15%).
    public var step = 0.15

    public init() {}
}

/// Two-hand pinch zoom: spread the pinched hands to zoom in, bring them together to zoom out.
public struct ZoomRecognizer: Sendable, Equatable {
    public var settings: ZoomSettings
    public private(set) var isZooming = false
    private var anchor: Double?
    private var pointerPinchSince: Double?
    private var otherPinchSince: Double?

    public init(settings: ZoomSettings) {
        self.settings = settings
    }

    /// `pointer` and `other` are the two hands' pinch states (nil when a hand is absent).
    /// Returns zoom steps for this frame.
    public mutating func update(
        pointer: (pinched: Bool, at: Point)?, other: (pinched: Bool, at: Point)?, at t: Double
    ) -> [ZoomDirection] {
        pointerPinchSince = pointer?.pinched == true ? (pointerPinchSince ?? t) : nil
        otherPinchSince = other?.pinched == true ? (otherPinchSince ?? t) : nil
        guard let pointer, let other, let a = pointerPinchSince, let b = otherPinchSince else {
            isZooming = false
            anchor = nil
            return []
        }
        let distance = pointer.at.distance(to: other.at)
        guard isZooming else {
            guard abs(a - b) <= settings.together, distance > 0 else { return [] }
            isZooming = true
            anchor = distance
            return []
        }
        guard let anchor else { return [] }
        let ratio = distance / anchor
        if ratio >= 1 + settings.step {
            self.anchor = distance
            return [.zoomIn]
        }
        if ratio <= 1 / (1 + settings.step) {
            self.anchor = distance
            return [.zoomOut]
        }
        return []
    }

    /// True while one hand is pinched and the other could still join within the window.
    public func mightStart(at t: Double) -> Bool {
        isZooming
            || [pointerPinchSince, otherPinchSince].contains { since in
                since.map { t - $0 <= settings.together } ?? false
            }
    }
}
