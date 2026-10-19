import Foundation
import HandyControl
import HandyCore
import HandyOutput
import Observation
import os

/// The composition root for the running app: owns the session (engine + perception pipeline),
/// live tracking, OS output, the HUD, the stop hotkey and the handyctl control socket.
@MainActor
@Observable
public final class AppModel {
    public private(set) var mode: Engine.Mode = .off
    let tracking: LiveTracking
    @ObservationIgnored private var session = Session(engine: Engine(mode: .off))
    @ObservationIgnored private var output = OutputDriver(sink: CGEventSink(), environment: LivePointerEnvironment())
    @ObservationIgnored private var lastFrameTime = 0.0
    @ObservationIgnored private var recentEvents: [TimedEvent] = []
    /// Collects every event while a clip is injected; nil otherwise.
    @ObservationIgnored private var injectedEvents: [TimedEvent]?
    private var injecting: Bool { injectedEvents != nil }
    @ObservationIgnored private var stopHotKey: GlobalHotKey?
    @ObservationIgnored private var controlServer: ControlServer?
    @ObservationIgnored private var hud: HUDPanel?
    @ObservationIgnored private lazy var cursorRing = CursorRingPanel()
    @ObservationIgnored private var hudState: HUDState?
    @ObservationIgnored private var hideHUDTask: Task<Void, Never>?
    @ObservationIgnored private(set) var lastAction: String?
    private static let log = Logger(subsystem: "dev.handy", category: "app")

    public init() {
        var process: (LandmarkFrame) -> Void = { _ in }
        tracking = LiveTracking { process($0) }
        process = { [weak self] frame in
            guard let self, !self.injecting else { return }
            self.process(frame)
        }
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
        updateCursorRing()
    }

    private func updateCursorRing() {
        let status = session.engine.status(at: lastFrameTime)
        let shown = (status.mode == .engaged || status.mode == .dragging) && !injecting
        cursorRing.update(closeness: shown ? status.pinch : nil, pressed: status.pinch == 1)
    }

    private func apply(_ events: [TimedEvent]) {
        injectedEvents?.append(contentsOf: events)
        for timed in events {
            recentEvents.append(timed)
            if case .modeChanged(let mode) = timed.event { changeMode(to: mode) }
            output.handle(timed.event, at: timed.t)
            if let description = timed.event.actionDescription { lastAction = description }
        }
        if recentEvents.count > 40 { recentEvents.removeFirst(recentEvents.count - 40) }
    }

    private func changeMode(to mode: Engine.Mode) {
        let wasOff = self.mode == .off
        self.mode = mode
        guard !injecting else { return }
        if mode != .engaged, mode != .dragging { cursorRing.update(closeness: nil, pressed: false) }
        if mode == .off {
            tracking.stop()
            session.resetTracking()
            lastAction = nil
        } else if wasOff {
            tracking.start()
        }
    }

    // MARK: HUD

    var currentHUD: HUDState {
        HUDState.make(status: session.engine.status(at: lastFrameTime), lastAction: lastAction, problem: problem)
    }

    /// The most pressing thing to say plainly in the HUD.
    private var problem: String? {
        if let camera = tracking.problem { return camera }
        if output.isBlocked, !AccessibilityPermission.isGranted { return "Accessibility permission needed" }
        return nil
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
        if mode == .off, problem == nil {
            hideHUDTask = Task { [weak panel] in
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                panel?.hide()
            }
        }
    }

    // MARK: handyctl

    var snapshot: AppStateSnapshot {
        AppStateSnapshot(
            mode: mode, stopHotKey: stopHotKey == nil ? nil : GlobalHotKey.stopDisplay,
            camera: tracking.camera.description, recording: tracking.recordingURL?.path(percentEncoded: false),
            perception: tracking.stats,
            hud: hudState.map {
                HUDSnapshot(visible: hud?.isVisible ?? false, title: $0.title, detail: $0.detail, progress: $0.progress)
            },
            accessibilityGranted: AccessibilityPermission.isGranted,
            output: OutputStats(posted: output.posted, refused: output.failed, blocked: output.isBlocked),
            lastEvents: recentEvents,
            settings: session.engine.settings)
    }

    private func handle(_ request: ControlRequest) async -> ControlResponse {
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
        case .inject(let frames, let record, let realtime):
            guard !injecting else { return ControlResponse(ok: false, error: "already injecting", state: snapshot) }
            let result = await inject(frames, record: record, realtime: realtime)
            return ControlResponse(state: snapshot, injected: result)
        }
    }

    /// Feeds a clip through the app's own session in place of the camera. Live frames are ignored
    /// meanwhile; afterwards the session starts fresh so clip and camera timestamps never mix.
    private func inject(_ frames: [LandmarkFrame], record: Bool, realtime: Bool) async -> InjectResult {
        injectedEvents = []
        let liveOutput = output
        let recorder = RecordingSink()
        if record { output = OutputDriver(sink: recorder, environment: VirtualPointerEnvironment()) }
        let wasOff = mode == .off
        session = Session(engine: Engine(mode: .watching, settings: session.engine.settings))
        mode = .watching
        let start = ContinuousClock.now
        for frame in frames {
            if realtime, let first = frames.first {
                try? await Task.sleep(until: start + .seconds(frame.t - first.t))
            }
            process(frame)
        }
        let events = injectedEvents ?? []
        output = liveOutput
        session = Session(engine: Engine(mode: wasOff ? .off : .watching, settings: session.engine.settings))
        mode = wasOff ? .off : .watching
        injectedEvents = nil
        updateHUD()
        return InjectResult(events: events, actions: recorder.actions)
    }
}

extension Engine.Event {
    /// What the HUD names as the last action, for events that act on the OS.
    var actionDescription: String? {
        switch self {
        case .modeChanged, .moveCursor, .dragMoved: nil
        case .click(.left, 1): "Click"
        case .click(.left, 2): "Double click"
        case .click(.left, _): "Triple click"
        case .click(.right, _): "Right click"
        case .dragBegan: "Drag"
        case .dragEnded: "Drop"
        }
    }
}
