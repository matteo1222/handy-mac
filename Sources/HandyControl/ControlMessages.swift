import Foundation
import HandyCore

/// One request per connection, newline-terminated JSON, answered by one JSON line.
public enum ControlRequest: Codable, Sendable, Equatable {
    case state
    case command(Engine.Command)
    case record(Bool)
    /// Renders one of Handy's own views (`hud`, `hud-gallery`, ...) to a PNG at `path`.
    case screenshot(target: String, path: String)
    /// Runs frames through the app's session instead of the camera. With `record`, output actions
    /// are captured and returned instead of posted. With `realtime`, frames are paced by their timestamps.
    case inject(frames: [LandmarkFrame], record: Bool, realtime: Bool)
    /// Stages a camera condition (inUse, disconnected, resumed, dark, bright) for HUD checks.
    case simulateCamera(event: String)
    /// Clicks the current problem's one-click fix.
    case applyFix
    /// Runs a catalog action (a `NamedAction` raw value); with `record` the output is captured, not posted.
    case perform(action: String, record: Bool)
}

/// What an injected clip did inside the app.
public struct InjectResult: Codable, Sendable, Equatable {
    public var events: [TimedEvent]
    public var actions: [OutputAction]

    public init(events: [TimedEvent], actions: [OutputAction]) {
        self.events = events
        self.actions = actions
    }
}

public struct ControlResponse: Codable, Sendable, Equatable {
    public var ok: Bool
    public var error: String?
    public var state: AppStateSnapshot?
    public var injected: InjectResult?

    public init(ok: Bool = true, error: String? = nil, state: AppStateSnapshot? = nil, injected: InjectResult? = nil) {
        self.ok = ok
        self.error = error
        self.state = state
        self.injected = injected
    }
}

/// What `handyctl state` prints about the running app.
public struct AppStateSnapshot: Codable, Sendable, Equatable {
    public var mode: Engine.Mode
    public var version: String
    /// The global stop hotkey, or nil when the system refused to register it.
    public var stopHotKey: String?
    public var camera: String
    public var recording: String?
    public var perception: PerceptionStats?
    public var hud: HUDSnapshot?
    public var accessibilityGranted: Bool?
    /// OS actions posted and refused since launch.
    public var output: OutputStats?
    /// The most recent engine events, oldest first.
    public var lastEvents: [TimedEvent]
    public var settings: EngineSettings?

    public init(
        mode: Engine.Mode, version: String = BuildInfo.version, stopHotKey: String? = nil, camera: String = "off",
        recording: String? = nil, perception: PerceptionStats? = nil, hud: HUDSnapshot? = nil,
        accessibilityGranted: Bool? = nil, output: OutputStats? = nil, lastEvents: [TimedEvent] = [],
        settings: EngineSettings? = nil
    ) {
        self.output = output
        self.hud = hud
        self.accessibilityGranted = accessibilityGranted
        self.lastEvents = lastEvents
        self.settings = settings
        self.mode = mode
        self.version = version
        self.stopHotKey = stopHotKey
        self.camera = camera
        self.recording = recording
        self.perception = perception
    }
}

public struct OutputStats: Codable, Sendable, Equatable {
    public var posted: Int
    public var refused: Int
    public var blocked: Bool

    public init(posted: Int, refused: Int, blocked: Bool) {
        self.posted = posted
        self.refused = refused
        self.blocked = blocked
    }
}

/// What the HUD pill currently says.
public struct HUDSnapshot: Codable, Sendable, Equatable {
    public var visible: Bool
    public var title: String
    public var detail: String?
    public var progress: Double?
    /// The one-click fix the pill offers, if any.
    public var fix: String?

    public init(visible: Bool, title: String, detail: String?, progress: Double?, fix: String? = nil) {
        self.visible = visible
        self.title = title
        self.detail = detail
        self.progress = progress
        self.fix = fix
    }
}

/// Live perception timings over the last few hundred frames, in milliseconds.
public struct PerceptionStats: Codable, Sendable, Equatable {
    public var frames: Int
    public var inference: Summary
    public var filterFeaturesEngine: Summary
    public var handsInLastFrame: Int
    public var idle: Bool
    public var brightness: Double

    public init(
        frames: Int, inference: Summary, filterFeaturesEngine: Summary, handsInLastFrame: Int, idle: Bool,
        brightness: Double
    ) {
        self.frames = frames
        self.inference = inference
        self.filterFeaturesEngine = filterFeaturesEngine
        self.handsInLastFrame = handsInLastFrame
        self.idle = idle
        self.brightness = brightness
    }
}

public enum ControlSocket {
    /// `HANDY_CONTROL_SOCKET` overrides the path, so a verification instance never shares a socket
    /// with the user's own Handy.
    public static var defaultPath: String {
        if let override = ProcessInfo.processInfo.environment["HANDY_CONTROL_SOCKET"], !override.isEmpty {
            return override
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Handy/control.sock").path(percentEncoded: false)
    }
}
