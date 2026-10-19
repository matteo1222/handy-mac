import AppKit
import HandyCore
import HandyOutput
import HandyPerception
import Observation

/// Drives the first-run tutorial. Permissions are asked in context: Camera when the user clicks
/// Start, Accessibility when the tutorial reaches the first click. The tutorial doubles as calibration.
@MainActor
@Observable
final class OnboardingModel {
    private(set) var tutorial = Tutorial()
    private(set) var advice = FramingAdvice.raiseHand
    private(set) var camera = CameraPermission.current
    private(set) var accessibilityGranted = AccessibilityPermission.isGranted
    private(set) var calibration: Calibration?
    /// Seconds the framing advice has been "good", to enable Continue.
    private(set) var goodFor = 0.0

    @ObservationIgnored private var recorder = CalibrationRecorder()
    @ObservationIgnored private var lastFrameTime: Double?
    @ObservationIgnored private var accessibilityPoll: Task<Void, Never>?
    @ObservationIgnored private let startTracking: () -> Void
    @ObservationIgnored private let finish: (Calibration?) -> Void

    init(startTracking: @escaping () -> Void, finish: @escaping (Calibration?) -> Void) {
        self.startTracking = startTracking
        self.finish = finish
    }

    var step: Tutorial.Step { tutorial.step }

    /// "Start tutorial": the moment Handy first asks for the camera.
    func start() async {
        camera = CameraPermission.current
        if camera == .notDetermined { camera = await CameraPermission.request() }
        tutorial.continueFromButton()
        guard camera == .granted else { return }
        tutorial.continueFromButton()
        startTracking()
    }

    func retryCamera() async {
        camera = CameraPermission.current
        guard camera == .granted, step == .cameraPermission else { return }
        tutorial.continueFromButton()
        startTracking()
    }

    func continueFromFraming() {
        guard step == .framing else { return }
        tutorial.continueFromButton()
    }

    func handle(_ event: Engine.Event) {
        let before = step
        tutorial.handle(event)
        if step != before { stepChanged() }
    }

    func observe(_ frame: FrameFeatures, brightness: Double, aspect: Double, mode: Engine.Mode) {
        recorder.observe(frame, step: step, mode: mode)
        let next = FramingAdvice.advise(frame, brightness: brightness, aspect: aspect)
        let dt = lastFrameTime.map { frame.t - $0 } ?? 0
        lastFrameTime = frame.t
        goodFor = next == .good ? goodFor + max(dt, 0) : 0
        if next != advice { advice = next }
    }

    var canContinueFromFraming: Bool { goodFor >= 1 }

    private func stepChanged() {
        switch step {
        case .click where !accessibilityGranted:
            AccessibilityPermission.request()
            pollAccessibility()
        case .done:
            calibration = recorder.calibration()
            finish(calibration)
        default:
            break
        }
    }

    /// Accessibility has no callback; check once a second until it is granted.
    private func pollAccessibility() {
        accessibilityPoll?.cancel()
        accessibilityPoll = Task { [weak self] in
            while !Task.isCancelled {
                if AccessibilityPermission.isGranted {
                    self?.accessibilityGranted = true
                    return
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// For screenshots: a model parked on a given step.
    static func preview(at step: Tutorial.Step) -> OnboardingModel {
        let model = OnboardingModel(startTracking: {}, finish: { _ in })
        model.tutorial = Tutorial(step: step)
        model.advice = step == .framing ? .moveRight : .good
        if step == .done {
            model.calibration = Calibration(
                handSize: 0.14, pinchPress: 0.22, pinchRelease: 0.38,
                reachBox: Rect(x: 0.6, y: 0.5, width: 0.5, height: 0.25))
        }
        return model
    }
}
