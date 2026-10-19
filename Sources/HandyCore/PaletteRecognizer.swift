import Foundation

public struct PaletteSettings: Sendable, Hashable, Codable {
    /// The other hand's pinch must be held this long to open the palette.
    public var hold = 0.4
    /// Moving the pinched hand this far (hand scales) highlights the slot it points at...
    public var highlight = 0.25
    /// ...and this far fires it.
    public var fire = 0.8

    public init() {}
}

/// The command palette: the other hand pinch-holds to open a radial menu of eight slots around
/// the cursor; moving the pinch decisively toward a slot fires it; releasing cancels.
public struct PaletteRecognizer: Sendable, Equatable {
    public var settings: PaletteSettings
    private var pinchSince: Double?
    private var origin: Point?
    public private(set) var highlighted: Int?

    public init(settings: PaletteSettings) {
        self.settings = settings
    }

    public var isOpen: Bool { origin != nil }

    /// `other` is the non-pointer hand with its pinch state; `pointerPinching` blocks opening (that is a zoom).
    public mutating func update(
        other: PinchReading?, pointerPinching: Bool, at t: Double
    ) -> [Engine.Event] {
        guard let other, other.pinched else {
            pinchSince = nil
            return close()
        }
        guard let origin else {
            let since = pinchSince ?? t
            pinchSince = since
            guard !pointerPinching, t - since >= settings.hold else { return [] }
            self.origin = other.at
            highlighted = nil
            return [.palette(.opened)]
        }
        let offset = (other.at - origin) / other.scale
        if offset.length >= settings.fire {
            let slot = Self.slot(for: offset)
            self.origin = nil
            highlighted = nil
            pinchSince = nil
            return [.palette(.fired(slot: slot))]
        }
        let slot = offset.length >= settings.highlight ? Self.slot(for: offset) : nil
        guard slot != highlighted else { return [] }
        highlighted = slot
        return [.palette(.highlighted(slot: slot))]
    }

    /// Closes without firing.
    public mutating func close() -> [Engine.Event] {
        guard origin != nil else { return [] }
        origin = nil
        highlighted = nil
        return [.palette(.cancelled)]
    }

    /// Slot 0 is straight up; slots run clockwise in 45° sectors (image y points down).
    public static func slot(for offset: Point) -> Int {
        let angle = atan2(offset.x, -offset.y)
        let sector = Int(((angle / (.pi / 4)).rounded() + Double(PaletteLayout.slotCount)))
        return sector % PaletteLayout.slotCount
    }
}

/// One hand's thumb-index pinch: whether it is closed, where (midway between the tips) and the hand's scale.
public struct PinchReading: Sendable, Equatable {
    public var pinched: Bool
    public var at: Point
    public var scale: Double

    public init(pinched: Bool, at: Point, scale: Double) {
        self.pinched = pinched
        self.at = at
        self.scale = scale
    }

    /// Nil when either tip is missing. A pinch counts only with the index reaching out from the palm.
    public init?(_ hand: HandFeatures?, settings: ClickSettings) {
        guard let hand, let thumb = hand[.thumbTip], let index = hand[.indexTip] else { return nil }
        pinched = (hand.pinchIndex ?? 1) < settings.press && hand.reach.index >= settings.minFingerReach
        at = (thumb + index) / 2
        scale = hand.scale
    }
}

public enum PaletteEvent: Sendable, Equatable, Codable {
    case opened
    case highlighted(slot: Int?)
    case fired(slot: Int)
    case cancelled
}
