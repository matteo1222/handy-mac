import Foundation
import HandyCore

/// One request per connection, newline-terminated JSON, answered by one JSON line.
public enum ControlRequest: Codable, Sendable, Equatable {
    case state
    case command(Engine.Command)
}

public struct ControlResponse: Codable, Sendable, Equatable {
    public var ok: Bool
    public var error: String?
    public var state: AppStateSnapshot?

    public init(ok: Bool = true, error: String? = nil, state: AppStateSnapshot? = nil) {
        self.ok = ok
        self.error = error
        self.state = state
    }
}

/// What `handyctl state` prints about the running app.
public struct AppStateSnapshot: Codable, Sendable, Equatable {
    public var mode: Engine.Mode
    public var version: String
    /// The global stop hotkey, or nil when the system refused to register it.
    public var stopHotKey: String?

    public init(mode: Engine.Mode, version: String = BuildInfo.version, stopHotKey: String? = nil) {
        self.mode = mode
        self.version = version
        self.stopHotKey = stopHotKey
    }
}

public enum ControlSocket {
    public static var defaultPath: String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "Handy/control.sock").path(percentEncoded: false)
    }
}
