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
    @ObservationIgnored private var hud: HUDPanel?
    @ObservationIgnored private var hudState: HUDState?
    @ObservationIgnored private var hideHUDTask: Task<Void, Never>?
    @ObservationIgnored private(set) var lastAction: String?
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
        updateHUD()
    }

    private func process(_ frame: LandmarkFrame) {
        lastFrameTime = frame.t
        apply(session.process(frame))
        tracking.publishDebug(session.lastFeatures, for: frame)
        updateHUD()
    }

    var currentHUD: HUDState {
        HUDState.make(
            status: session.engine.status(at: lastFrameTime), lastAction: lastAction, problem: tracking.problem)
    }

    /// Shows the pill while Handy is on; after turning off it says "Off" briefly, then hides.
    private func updateHUD() {
        let state = currentHUD
        guard state != hudState else { return }
        hudState = state
        let panel = hud ?? HUDPanel(state: state)
        hud = panel
        hideHUDTask?.cancel()
        panel.show(state)
        if mode == .off, tracking.problem == nil {
            hideHUDTask = Task { [weak panel] in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                panel?.hide()
            }
        }
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
            perception: tracking.stats,
            hud: hudState.map {
                HUDSnapshot(visible: hud?.isVisible ?? false, title: $0.title, detail: $0.detail, progress: $0.progress)
            })
    }

    private func handle(_ request: ControlRequest) -> ControlResponse {
        switch request {
        case .state:
            return ControlResponse(state: snapshot)
        case .command(let command):
            send(command)
            return ControlResponse(state: snapshot)
        case .screenshot(let target, let path):
            do {
                try Screenshots.render(target, model: self, to: URL(filePath: path))
                return ControlResponse(state: snapshot)
            } catch {
                return ControlResponse(ok: false, error: "screenshot: \(error)", state: snapshot)
            }
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
