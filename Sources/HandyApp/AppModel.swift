import HandyControl
import HandyCore
import Observation
import os

/// Owns the engine for the running app and exposes its state to the menu bar and HUD.
@MainActor
@Observable
public final class AppModel {
    public private(set) var mode: Engine.Mode = .off
    @ObservationIgnored private var engine = Engine()
    @ObservationIgnored private var stopHotKey: GlobalHotKey?
    @ObservationIgnored private var controlServer: ControlServer?
    private static let log = Logger(subsystem: "dev.handy", category: "app")

    public init() {}

    /// Registers the global stop hotkey and the handyctl control socket. Called once at launch.
    public func activate() {
        guard stopHotKey == nil else { return }
        stopHotKey = GlobalHotKey(keyCode: GlobalHotKey.stopKeyCode, modifiers: GlobalHotKey.stopModifiers) {
            [weak self] in
            self?.send(.stop)
        }
        do {
            controlServer = try ControlServer { [weak self] request in
                await self?.handle(request) ?? ControlResponse(ok: false, error: "app is shutting down")
            }
        } catch {
            Self.log.error("control socket unavailable: \(String(describing: error))")
        }
    }

    public func send(_ command: Engine.Command) {
        for event in engine.handle(.command(command)) {
            switch event {
            case .modeChanged(let mode): self.mode = mode
            }
        }
    }

    var snapshot: AppStateSnapshot {
        AppStateSnapshot(mode: mode, stopHotKey: stopHotKey == nil ? nil : GlobalHotKey.stopDisplay)
    }

    private func handle(_ request: ControlRequest) -> ControlResponse {
        switch request {
        case .state:
            return ControlResponse(state: snapshot)
        case .command(let command):
            send(command)
            return ControlResponse(state: snapshot)
        }
    }
}
