import Foundation
import HandyControl
import HandyCore
import Observation
import os

/// The composition root for the running app: owns the session (engine + perception pipeline),
/// live tracking, the stop hotkey and the handyctl control socket.
@MainActor
@Observable
public final class AppModel {
    public private(set) var mode: Engine.Mode = .off
    let tracking: LiveTracking
    @ObservationIgnored private var session = Session(engine: Engine(mode: .off))
    @ObservationIgnored private var lastFrameTime = 0.0
    @ObservationIgnored private var stopHotKey: GlobalHotKey?
    @ObservationIgnored private var controlServer: ControlServer?
    private static let log = Logger(subsystem: "dev.handy", category: "app")

    public init() {
        var process: (LandmarkFrame) -> Void = { _ in }
        tracking = LiveTracking { process($0) }
        process = { [weak self] frame in self?.process(frame) }
    }

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
        apply(session.send(command, at: lastFrameTime))
    }

    private func process(_ frame: LandmarkFrame) {
        lastFrameTime = frame.t
        apply(session.process(frame))
        tracking.publishDebug(session.lastFeatures, for: frame)
    }

    private func apply(_ events: [TimedEvent]) {
        for timed in events {
            switch timed.event {
            case .modeChanged(let mode):
                self.mode = mode
                if mode == .off {
                    tracking.stop()
                    session.resetTracking()
                } else {
                    tracking.start()
                }
            }
        }
    }

    var snapshot: AppStateSnapshot {
        AppStateSnapshot(
            mode: mode, stopHotKey: stopHotKey == nil ? nil : GlobalHotKey.stopDisplay,
            camera: tracking.camera.description, recording: tracking.recordingURL?.path(percentEncoded: false),
            perception: tracking.stats)
    }

    private func handle(_ request: ControlRequest) -> ControlResponse {
        switch request {
        case .state:
            return ControlResponse(state: snapshot)
        case .command(let command):
            send(command)
            return ControlResponse(state: snapshot)
        case .record(let on):
            do {
                try tracking.setRecording(on)
                return ControlResponse(state: snapshot)
            } catch {
                return ControlResponse(ok: false, error: "recording: \(error.localizedDescription)", state: snapshot)
            }
        }
    }
}
