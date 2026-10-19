import AppKit
import HandyControl
import HandyCore
import HandyOutput
import HandyPerception
import Observation
import SwiftUI
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
    @ObservationIgnored private var router = ActionRouter()
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
    private(set) var onboarding: OnboardingModel?
    @ObservationIgnored private var onboardingWindow: NSWindow?
    private static let log = Logger(subsystem: "dev.handy", category: "app")

    public init() {
        var process: (LandmarkFrame) -> Void = { _ in }
        var changed: () -> Void = {}
        tracking = LiveTracking(onFrame: { process($0) }, onChange: { changed() })
        tracking.preferredCameraID = UserDefaults.standard.string(forKey: Self.cameraKey)
        process = { [weak self] frame in
            guard let self, !self.injecting else { return }
            self.process(frame)
        }
        changed = { [weak self] in self?.updateHUD() }
        if let calibration = CalibrationStore.load() { applyCalibration(calibration) }
    }

}

// MARK: Onboarding

extension AppModel {

    private static let onboardedKey = "onboarded"

    /// Opens the tutorial window; shown automatically on first launch.
    func showOnboarding() {
        let onboarding =
            onboarding
            ?? OnboardingModel(
                startTracking: { [weak self] in self?.send(.start) },
                finish: { [weak self] calibration in self?.finishOnboarding(calibration) })
        self.onboarding = onboarding
        let window =
            onboardingWindow
            ?? NSWindow(
                contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to Handy"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(model: onboarding) { [weak self] in self?.closeOnboarding() })
        window.center()
        onboardingWindow = window
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func closeOnboarding() {
        onboardingWindow?.close()
        onboarding = nil
    }

    private func finishOnboarding(_ calibration: Calibration?) {
        UserDefaults.standard.set(true, forKey: Self.onboardedKey)
        guard let calibration else { return }
        do {
            try CalibrationStore.save(calibration)
        } catch {
            Self.log.error("saving calibration failed: \(error.localizedDescription)")
        }
        applyCalibration(calibration)
    }

    private func applyCalibration(_ calibration: Calibration) {
        var settings = session.engine.settings
        calibration.apply(to: &settings)
        session.configure(settings)
    }

    var needsOnboarding: Bool { !UserDefaults.standard.bool(forKey: Self.onboardedKey) }
}

extension AppModel {

    private static let cameraKey = "cameraID"

    /// The chosen camera, persisted across launches. Switching restarts a running camera.
    var cameraID: String? {
        get { tracking.preferredCameraID }
        set {
            tracking.preferredCameraID = newValue
            UserDefaults.standard.set(newValue, forKey: Self.cameraKey)
            if mode != .off { tracking.restart() }
        }
    }

    /// Runs a problem's one-click fix.
    func apply(_ fix: Problem.Fix) {
        switch fix {
        case .retryCamera:
            tracking.restart()
        case .useFallbackCamera:
            cameraID = CameraDevices.fallback()?.id
        case .openCameraSettings, .openAccessibilitySettings:
            if let url = fix.settingsURL { NSWorkspace.shared.open(url) }
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
        if needsOnboarding { showOnboarding() }
    }

    public func send(_ command: Engine.Command) {
        apply(session.send(command, at: lastFrameTime))
        updateHUD()
    }

    private func process(_ frame: LandmarkFrame) {
        lastFrameTime = frame.t
        if !injecting, abs(session.engine.settings.frameAspect - tracking.lastAspect) > 0.01 {
            var settings = session.engine.settings
            settings.frameAspect = tracking.lastAspect
            session.configure(settings)
        }
        apply(session.process(frame))
        tracking.publishDebug(session.lastFeatures, for: frame)
        if let onboarding, let features = session.lastFeatures {
            onboarding.observe(
                features, brightness: tracking.lastBrightness, aspect: tracking.lastAspect, mode: session.engine.mode)
        }
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
            onboarding?.handle(timed.event)
            if case .modeChanged(let mode) = timed.event { changeMode(to: mode) }
            output.handle(timed.event, at: timed.t)
            if let description = timed.event.actionDescription { lastAction = description }
            for action in router.actions(for: timed.event) {
                output.perform(action)
                lastAction = action.description
            }
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
        let status = session.engine.status(at: lastFrameTime)
        let binding = status.oneShot.flatMap { router.bindings.oneShots[$0] }?.description
        return HUDState.make(status: status, lastAction: lastAction, problem: problem, binding: binding)
    }

    /// The most pressing thing to say plainly in the HUD.
    var problem: Problem? {
        if let camera = tracking.problem { return camera }
        if output.isBlocked, !AccessibilityPermission.isGranted { return .accessibilityNeeded }
        return nil
    }

    /// Shows the pill while Handy is on; after turning off it says "Off" briefly, then hides.
    private func updateHUD() {
        let state = currentHUD
        guard state != hudState else { return }
        hudState = state
        let panel = hud ?? HUDPanel(state: state) { [weak self] fix in self?.apply(fix) }
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

}

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

    private func handle(_ request: ControlRequest) async -> ControlResponse {
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
        case .simulateCamera(let event):
            return attempt("camera") { try simulate(named: event) }
        case .applyFix:
            return attempt("fix") {
                guard let fix = problem?.fix else { throw ControlError("no problem with a fix right now") }
                apply(fix)
            }
        case .inject(let frames, let record, let realtime):
            guard !injecting else { return ControlResponse(ok: false, error: "already injecting", state: snapshot) }
            let result = await inject(frames, record: record, realtime: realtime)
            return ControlResponse(state: snapshot, injected: result)
        }
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
    fileprivate func simulate(named name: String) throws {
        guard let event = SimulatedCameraEvent(rawValue: name) else {
            let names = SimulatedCameraEvent.allCases.map(\.rawValue).joined(separator: ", ")
            throw ControlError("unknown camera event \(name); use \(names)")
        }
        simulate(event)
    }

    fileprivate func simulate(_ event: SimulatedCameraEvent) {
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
        case .scroll, .oneShot, .flick, .swipe: nil
        }
    }
}
