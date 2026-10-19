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
    public internal(set) var mode: Engine.Mode = .off
    let tracking: LiveTracking
    @ObservationIgnored var session = Session(engine: Engine(mode: .off))
    @ObservationIgnored var output = OutputDriver(sink: CGEventSink(), environment: LivePointerEnvironment())
    @ObservationIgnored private var lastFrameTime = 0.0
    @ObservationIgnored var recentEvents: [TimedEvent] = []
    /// The last few seconds of frames, for oops samples.
    @ObservationIgnored private var recentFrames: [LandmarkFrame] = []
    private(set) var oopsCount = OopsLog.count()
    @ObservationIgnored private var router = ActionRouter()
    /// Collects every event while a clip is injected; nil otherwise.
    @ObservationIgnored var injectedEvents: [TimedEvent]?
    var injecting: Bool { injectedEvents != nil }
    @ObservationIgnored var stopHotKey: GlobalHotKey?
    @ObservationIgnored private var controlServer: ControlServer?
    @ObservationIgnored var hud: HUDPanel?
    @ObservationIgnored private lazy var cursorRing = CursorRingPanel()
    @ObservationIgnored private lazy var paletteOverlay = PalettePanel()
    @ObservationIgnored private lazy var cheatSheetPanel = CheatSheetPanel()
    @ObservationIgnored private var cheatSheetHotKey: GlobalHotKey?
    @ObservationIgnored lazy var updates = Updates()
    @ObservationIgnored private var usage = UsageMeter()
    @ObservationIgnored private var usageFlush: Task<Void, Never>?
    /// Today's usage, for the menu.
    private(set) var usageToday = UsageStore.load()[UsageStore.day(Date())] ?? UsageStats()
    @ObservationIgnored var hudState: HUDState?
    @ObservationIgnored private var hideHUDTask: Task<Void, Never>?
    @ObservationIgnored private(set) var lastAction: String?
    /// A problem that clears itself after a few seconds, such as asking for Dictation when it is off.
    @ObservationIgnored private var transientProblem: Problem?
    @ObservationIgnored private var transientTask: Task<Void, Never>?
    private(set) var onboarding: OnboardingModel?
    @ObservationIgnored private var onboardingWindow: NSWindow?
    private static let log = Logger(subsystem: "dev.handy", category: "app")

    /// The user's preset, sensitivity and camera. Saved and applied on every change.
    var settings = SettingsStore.load() {
        didSet {
            guard settings != oldValue else { return }
            do {
                try SettingsStore.save(settings)
            } catch {
                Self.log.error("saving settings failed: \(error.localizedDescription)")
            }
            applyTuning()
            router.bindings.palette = settings.palette
            if settings.cameraID != oldValue.cameraID {
                tracking.preferredCameraID = settings.cameraID
                if mode != .off { tracking.restart() }
            }
        }
    }
    @ObservationIgnored var calibration = CalibrationStore.load()
    /// Live sensitivity meters, refreshed only while the settings window shows them.
    private(set) var meters: [SensitivityKey: Double] = [:]
    @ObservationIgnored var metersVisible = false
    @ObservationIgnored private var meterTick = 0

    public init() {
        var process: (LandmarkFrame) -> Void = { _ in }
        var changed: () -> Void = {}
        tracking = LiveTracking(onFrame: { process($0) }, onChange: { changed() })
        tracking.preferredCameraID = settings.cameraID
        process = { [weak self] frame in
            guard let self, !self.injecting else { return }
            self.process(frame)
        }
        changed = { [weak self] in self?.updateHUD() }
        applyTuning()
        router.bindings.palette = settings.palette
        AppModel.current = self
    }

    /// The running app's model, for App Intents.
    static weak var current: AppModel?

    /// Runs a catalog action now, from the menu bar, an App Intent or handyctl.
    func perform(_ action: NamedAction) {
        output.perform(action.action)
        lastAction = action.title
        updateHUD()
    }

    /// Shows or hides the cheat sheet for the frontmost app.
    func setCheatSheet(_ shown: Bool) {
        guard shown else { return cheatSheetPanel.hide() }
        let app = NSWorkspace.shared.frontmostApplication
        cheatSheetPanel.show(
            entries: GestureGuide.entries(bindings: router.bindings, app: app?.bundleIdentifier),
            appName: app?.localizedName)
    }

    func toggleCheatSheet() {
        setCheatSheet(!cheatSheetPanel.isVisible)
    }

    var guideEntries: [GuideEntry] {
        GestureGuide.entries(bindings: router.bindings, app: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    private func showPalette(_ event: PaletteEvent) {
        let layout = settings.palette.layout(for: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        switch event {
        case .opened: paletteOverlay.show(layout: layout, highlighted: nil)
        case .highlighted(let slot): paletteOverlay.show(layout: layout, highlighted: slot)
        case .fired, .cancelled: paletteOverlay.hide()
        }
    }

    /// Preset, then calibration, then sensitivity, into the running session.
    func applyTuning() {
        let tuning = settings.tuning(calibration: calibration)
        var engine = tuning.engine
        engine.frameAspect = session.engine.settings.frameAspect
        session.configure(engine)
        session.configure(tracker: tuning.tracker)
    }

    func updateMeters() {
        meterTick += 1
        guard metersVisible, meterTick % 3 == 0 else { return }
        let hand = session.lastFeatures?.hands.first { $0.chirality == session.engine.settings.pointerHand }
        let status = session.engine.status(at: lastFrameTime)
        meters = Dictionary(
            uniqueKeysWithValues: SensitivityKey.allCases.map { key in
                (key, SensitivityMeter.read(key, hand: hand, status: status, settings: session.engine.settings))
            })
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
        self.calibration = calibration
        applyTuning()
    }

    var needsOnboarding: Bool { !UserDefaults.standard.bool(forKey: Self.onboardedKey) }
}

extension AppModel {

    /// The chosen camera, persisted across launches. Switching restarts a running camera.
    var cameraID: String? {
        get { settings.cameraID }
        set { settings.cameraID = newValue }
    }

    private func recordOops(at t: Double) {
        do {
            try OopsLog.record(frames: recentFrames, at: t, undid: lastAction)
            oopsCount += 1
        } catch {
            Self.log.error("saving the oops sample failed: \(error.localizedDescription)")
        }
    }

    /// Saves the usage counted since the last flush into today's entry.
    func flushUsage() {
        let stats = usage.drain()
        do {
            try UsageStore.add(stats)
        } catch {
            Self.log.error("saving usage failed: \(error.localizedDescription)")
        }
        usageToday = UsageStore.load()[UsageStore.day(Date())] ?? UsageStats()
    }

    /// Shows a problem for a few seconds.
    func show(transient problem: Problem) {
        transientProblem = problem
        transientTask?.cancel()
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.transientProblem = nil
            self?.updateHUD()
        }
        updateHUD()
    }

    /// Runs a problem's one-click fix.
    func apply(_ fix: Problem.Fix) {
        if transientProblem?.fix == fix { transientProblem = nil }
        switch fix {
        case .retryCamera:
            tracking.restart()
        case .useFallbackCamera:
            cameraID = CameraDevices.fallback()?.id
        case .openCameraSettings, .openAccessibilitySettings, .openKeyboardSettings:
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
        cheatSheetHotKey = GlobalHotKey(
            keyCode: GlobalHotKey.cheatSheetKeyCode, modifiers: GlobalHotKey.stopModifiers
        ) { [weak self] in
            self?.toggleCheatSheet()
        }
        do {
            controlServer = try ControlServer { [weak self] request in
                await self?.handle(request) ?? ControlResponse(ok: false, error: "app is shutting down")
            }
        } catch {
            Self.log.error("control socket unavailable: \(String(describing: error))")
        }
        if needsOnboarding { showOnboarding() }
        usageFlush = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.flushUsage()
            }
        }
    }

    public func send(_ command: Engine.Command) {
        apply(session.send(command, at: lastFrameTime))
        updateHUD()
    }

    func process(_ frame: LandmarkFrame) {
        lastFrameTime = frame.t
        recentFrames.append(frame)
        if !injecting { usage.tick(at: frame.t) }
        if let first = recentFrames.first, frame.t - first.t > OopsLog.keep + 1 || frame.t < first.t {
            recentFrames.removeAll { frame.t - $0.t > OopsLog.keep + 1 || $0.t > frame.t }
        }
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
        updateMeters()
    }

    private func updateCursorRing() {
        let status = session.engine.status(at: lastFrameTime)
        let shown = (status.mode == .engaged || status.mode == .dragging) && !injecting
        cursorRing.update(closeness: shown ? status.pinch : nil, pressed: status.pinch == 1)
    }

    private func apply(_ events: [TimedEvent]) {
        injectedEvents?.append(contentsOf: events)
        for timed in events {
            if !injecting { usage.observe(timed.event) }
            recentEvents.append(timed)
            onboarding?.handle(timed.event)
            if case .modeChanged(let mode) = timed.event { changeMode(to: mode) }
            output.handle(timed.event, at: timed.t)
            if let description = timed.event.actionDescription { lastAction = description }
            if timed.event == .oops { recordOops(at: timed.t) }
            if case .palette(let event) = timed.event { showPalette(event) }
            if case .cheatSheet(let shown) = timed.event { setCheatSheet(shown) }
            let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            for action in router.actions(for: timed.event, app: app) {
                output.perform(action)
                lastAction = action.description
                if output.dictationUnavailable {
                    output.dictationUnavailable = false
                    show(transient: .dictationUnavailable)
                }
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
        if let transientProblem { return transientProblem }
        if output.isBlocked, !AccessibilityPermission.isGranted { return .accessibilityNeeded }
        return nil
    }

    /// Shows the pill while Handy is on; after turning off it says "Off" briefly, then hides.
    func updateHUD() {
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
        case .scroll, .oneShot, .flick, .swipe, .zoom, .oops, .palette, .cheatSheet: nil
        }
    }
}
