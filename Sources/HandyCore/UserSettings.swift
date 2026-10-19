import Foundation

/// Where the user sits: each preset stores the filter and threshold values that suit it.
public enum Preset: String, Sendable, Codable, CaseIterable {
    /// At the desk, about 0.6 m from the built-in camera.
    case desk
    /// On the couch, 1.5 to 3 m from a TV or external display: a small hand in the frame.
    case couch
    /// Presenting: zero tolerance for stray cursor motion; deliberate engage and keys.
    case presenter

    public var title: String {
        switch self {
        case .desk: "Desk"
        case .couch: "Couch"
        case .presenter: "Presenter"
        }
    }

    /// The tuned values: joint filter, pointer gain and thresholds.
    public var values: Tuning {
        var tracker = HandTracker.Settings()
        var engine = EngineSettings()
        switch self {
        case .desk:
            break
        case .couch:
            // A distant hand is a few pixels wide: filter harder, accept lower fingertip confidence,
            // and scale gains up because the palm crosses far less of the frame.
            tracker.filter = OneEuroSettings(minCutoff: 0.9, beta: 12)
            tracker.minJointConfidence = 0.25
            engine.pointer.slowGain *= 3
            engine.pointer.fastGain *= 3
            engine.pointer.filter = OneEuroSettings(minCutoff: 0.4, beta: 8)
            engine.scroll.gain *= 2.5
            engine.attention.maxYaw = 40
        case .presenter:
            engine.armHold = 0.45
            engine.pointer.deadband = 0.6
            engine.pointer.filter = OneEuroSettings(minCutoff: 0.35, beta: 3)
            engine.oneShot.hold = 0.6
            engine.flick.distance = 0.7
        }
        return Tuning(tracker: tracker, engine: engine)
    }
}

/// Everything a preset sets.
public struct Tuning: Sendable, Hashable, Codable {
    public var tracker: HandTracker.Settings
    public var engine: EngineSettings
}

/// The gesture families a user can make more or less sensitive.
public enum SensitivityKey: String, Sendable, Codable, CaseIterable {
    case engage
    case click
    case scroll
    case keys
    case flick
    case swipe

    public var title: String {
        switch self {
        case .engage: "Engage"
        case .click: "Click"
        case .scroll: "Scroll"
        case .keys: "Thumbs and shaka"
        case .flick: "Arrow flicks"
        case .swipe: "Spaces swipe"
        }
    }
}

/// The user's settings, stored as JSON. Versioned: older files decode with defaults for anything
/// they lack, and the decoder never rejects a file it can partly use.
public struct UserSettings: Sendable, Hashable, Codable {
    public static let currentVersion = 1

    public var version = UserSettings.currentVersion
    public var preset = Preset.desk
    /// 0 (least sensitive) ... 1 (most), 0.5 is the preset's own value.
    public var sensitivity: [SensitivityKey: Double] = [:]
    /// The chosen camera's unique ID; nil uses the system default.
    public var cameraID: String?
    /// Palette slots everywhere and per app.
    public var palette = PaletteBindings()

    public init(
        preset: Preset = .desk, sensitivity: [SensitivityKey: Double] = [:], cameraID: String? = nil,
        palette: PaletteBindings = PaletteBindings()
    ) {
        self.preset = preset
        self.sensitivity = sensitivity
        self.cameraID = cameraID
        self.palette = palette
    }

    public subscript(key: SensitivityKey) -> Double {
        get { sensitivity[key] ?? 0.5 }
        set { sensitivity[key] = min(max(newValue, 0), 1) }
    }

    private enum CodingKeys: String, CodingKey {
        case version, preset, sensitivity, cameraID, palette
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? container.decode(Int.self, forKey: .version)) ?? UserSettings.currentVersion
        preset = (try? container.decode(Preset.self, forKey: .preset)) ?? .desk
        let raw = (try? container.decode([String: Double].self, forKey: .sensitivity)) ?? [:]
        sensitivity = Dictionary(
            uniqueKeysWithValues: raw.compactMap { key, value in
                SensitivityKey(rawValue: key).map { ($0, min(max(value, 0), 1)) }
            })
        cameraID = try? container.decode(String.self, forKey: .cameraID)
        palette = (try? container.decode(PaletteBindings.self, forKey: .palette)) ?? PaletteBindings()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(UserSettings.currentVersion, forKey: .version)
        try container.encode(preset, forKey: .preset)
        try container.encode(
            Dictionary(uniqueKeysWithValues: sensitivity.map { ($0.key.rawValue, $0.value) }), forKey: .sensitivity)
        try container.encodeIfPresent(cameraID, forKey: .cameraID)
        try container.encode(palette, forKey: .palette)
    }

    /// The preset's tuning, then calibration, then the sensitivity sliders.
    public func tuning(calibration: Calibration?) -> Tuning {
        var tuning = preset.values
        calibration?.apply(to: &tuning.engine)
        // Each slider runs from half to one and a half times "as hard to trigger" at its ends.
        func scale(_ key: SensitivityKey) -> Double { 1.5 - self[key] }
        tuning.engine.armHold *= scale(.engage)
        let pressSpan = tuning.engine.click.release - tuning.engine.click.press
        tuning.engine.click.press = min(tuning.engine.click.press / scale(.click), tuning.engine.click.release - 0.05)
        tuning.engine.click.release = tuning.engine.click.press + pressSpan
        tuning.engine.scroll.enterDwell *= scale(.scroll)
        tuning.engine.oneShot.hold *= scale(.keys)
        tuning.engine.flick.distance *= scale(.flick)
        tuning.engine.swipe.distance *= scale(.swipe)
        return tuning
    }
}

/// How close the live hand is to triggering each gesture family, 0...1 where 1 is the threshold,
/// for the settings window's meters.
public enum SensitivityMeter {
    public static func read(_ key: SensitivityKey, hand: HandFeatures?, status: Engine.Status, settings: EngineSettings)
        -> Double
    {
        guard let hand else { return 0 }
        switch key {
        case .engage:
            if status.mode == .arming { return status.progress ?? 0 }
            let fingers = [Finger.index, .middle, .ring, .little].map { min(max(hand.reach[$0], 0), 1) }
            return min(fingers.reduce(0, +) / 4 / HandFeatures.extendedThreshold, 1)
        case .click:
            guard let pinch = [hand.pinchIndex, hand.pinchMiddle].compactMap({ $0 }).min() else { return 0 }
            let span = settings.click.previewStart - settings.click.press
            return min(max((settings.click.previewStart - pinch) / span, 0), 1)
        case .scroll:
            let up = min(hand.reach.index, hand.reach.middle) / 0.6
            let down = 1 - max(hand.reach.ring, hand.reach.little, 0) / 0.6
            return min(max(min(up, down), 0), 1)
        case .keys:
            return status.oneShot == nil ? 0 : status.progress ?? 0
        case .flick:
            // Palm speed in hand scales per second against the flick's required tip speed.
            let needed = settings.flick.distance / settings.flick.window
            return min(hand.velocity.length / hand.scale / needed, 1)
        case .swipe:
            let needed = settings.swipe.distance * settings.frameAspect / settings.swipe.window
            return min(hand.velocity.length / needed, 1)
        }
    }
}
