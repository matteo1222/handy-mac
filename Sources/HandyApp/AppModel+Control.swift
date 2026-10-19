import AppKit
import HandyControl
import HandyCore
import HandyOutput

// MARK: handyctl

extension AppModel {

    var snapshot: AppStateSnapshot {
        AppStateSnapshot(
            mode: mode, stopHotKey: stopHotKey == nil ? nil : GlobalHotKey.stopDisplay,
            camera: tracking.camera.description, recording: tracking.recordingURL?.path(percentEncoded: false),
            perception: tracking.stats,
            hud: hudState.map {
                HUDSnapshot(
                    visible: hud?.isVisible ?? false, title: $0.title, detail: $0.detail, progress: $0.progress,
                    fix: $0.fix?.title)
            },
            accessibilityGranted: AccessibilityPermission.isGranted,
            output: OutputStats(posted: output.posted, refused: output.failed, blocked: output.isBlocked),
            lastEvents: recentEvents,
            settings: session.engine.settings)
    }

    func handle(_ request: ControlRequest) async -> ControlResponse {
        switch request {
        case .state:
            return ControlResponse(state: snapshot)
        case .command(let command):
            send(command)
            return ControlResponse(state: snapshot)
        case .screenshot(let target, let path):
            return attempt("screenshot") { try Screenshots.render(target, model: self, to: URL(filePath: path)) }
        case .record(let on):
            return attempt("recording") { try tracking.setRecording(on) }
        case .simulateCamera, .applyFix:
            return handleCamera(request)
        case .usage:
            flushUsage()
            return ControlResponse(state: snapshot, usage: UsageReport(days: UsageStore.load()))
        case .perform(let name, let record):
            return perform(named: name, record: record)
        case .inject(let frames, let record, let realtime):
            guard !injecting else { return ControlResponse(ok: false, error: "already injecting", state: snapshot) }
            let result = await inject(frames, record: record, realtime: realtime)
            return ControlResponse(state: snapshot, injected: result)
        }
    }

    private func handleCamera(_ request: ControlRequest) -> ControlResponse {
        switch request {
        case .simulateCamera(let event):
            return attempt("camera") { try simulate(named: event) }
        case .applyFix:
            return attempt("fix") {
                guard let fix = problem?.fix else { throw ControlError("no problem with a fix right now") }
                apply(fix)
            }
        default:
            return ControlResponse(ok: false, error: "not a camera request", state: snapshot)
        }
    }

    private func perform(named name: String, record: Bool) -> ControlResponse {
        guard let action = NamedAction(rawValue: name) else {
            let names = NamedAction.allCases.map(\.rawValue).joined(separator: ", ")
            return ControlResponse(ok: false, error: "unknown action \(name); use \(names)", state: snapshot)
        }
        let liveOutput = output
        let recorder = RecordingSink()
        if record { output = OutputDriver(sink: recorder, environment: VirtualPointerEnvironment()) }
        perform(action)
        output = liveOutput
        return ControlResponse(state: snapshot, injected: InjectResult(events: [], actions: recorder.actions))
    }

    private func attempt(_ label: String, _ body: () throws -> Void) -> ControlResponse {
        do {
            try body()
            return ControlResponse(state: snapshot)
        } catch {
            return ControlResponse(ok: false, error: "\(label): \(error)", state: snapshot)
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
        applyTuning()
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
        applyTuning()
        mode = wasOff ? .off : .watching
        injectedEvents = nil
        updateHUD()
        return InjectResult(events: events, actions: recorder.actions)
    }
}

/// Camera conditions handyctl can stage, to check the HUD says them plainly without unplugging anything.
enum SimulatedCameraEvent: String, CaseIterable {
    case inUse
    case disconnected
    case resumed
    case dark
    case bright
}

struct ControlError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

extension AppModel {
    func simulate(named name: String) throws {
        guard let event = SimulatedCameraEvent(rawValue: name) else {
            let names = SimulatedCameraEvent.allCases.map(\.rawValue).joined(separator: ", ")
            throw ControlError("unknown camera event \(name); use \(names)")
        }
        simulate(event)
    }

    func simulate(_ event: SimulatedCameraEvent) {
        switch event {
        case .inUse: tracking.handle(.interrupted(.inUseByAnotherApp))
        case .disconnected: tracking.handle(.interrupted(.disconnected))
        case .resumed: tracking.handle(.resumed)
        case .dark:
            tracking.handle(.resumed)
            for step in 0...70 { tracking.observeBrightness(0.04, at: Double(step) / 30) }
        case .bright: tracking.observeBrightness(0.5, at: 10)
        }
        updateHUD()
    }
}
