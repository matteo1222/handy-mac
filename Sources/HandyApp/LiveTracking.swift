import Foundation
import HandyControl
import HandyCore
import HandyPerception
import HandyReplay
import Observation
import os

/// Camera → perception → session for the running app. The camera runs only while the engine is
/// not Off; every frame goes through the same `Session` that `handyctl replay` uses.
struct DebugFrame {
    var landmarks: LandmarkFrame
    var features: FrameFeatures
    var aspect: Double
}

@MainActor
@Observable
final class LiveTracking {
    enum CameraState: Equatable {
        case off
        case starting
        case live(String)
        case paused(CameraInterruption)
        case permissionDenied
        case failed(String)

        var description: String {
            switch self {
            case .off: "off"
            case .starting: "starting"
            case .live(let name): "live: \(name)"
            case .paused(let reason): "paused: \(reason.rawValue)"
            case .permissionDenied: "permission denied"
            case .failed(let message): "failed: \(message)"
            }
        }

        var isLive: Bool {
            if case .live = self { return true }
            return false
        }
    }

    private(set) var camera: CameraState = .off {
        didSet { if camera != oldValue { onChange() } }
    }
    private(set) var isTooDark = false {
        didSet { if isTooDark != oldValue { onChange() } }
    }
    private(set) var recordingURL: URL?
    /// The camera to use; nil means the system default. Persisted by the app's settings.
    var preferredCameraID: String?
    /// The most recent frame and its features, published only while the debug overlay is open.
    private(set) var debugFrame: DebugFrame?
    var publishesDebugFrames = false

    @ObservationIgnored private var capture: CameraCapture?
    @ObservationIgnored private var frameTask: Task<Void, Never>?
    @ObservationIgnored private var permissionTask: Task<Void, Never>?
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var recorder: LandmarkStreamWriter?
    @ObservationIgnored private var recordingOrigin: Double?
    @ObservationIgnored private var inference = RollingWindow()
    @ObservationIgnored private var pipeline = RollingWindow()
    @ObservationIgnored private var intervals = RollingWindow()
    @ObservationIgnored private var faceTimes = RollingWindow(capacity: 60)
    @ObservationIgnored private var lastFace: FaceSample?
    @ObservationIgnored private var frameCount = 0
    @ObservationIgnored private var last: PerceptionFrame?
    @ObservationIgnored private var darkness = DarknessMonitor()
    @ObservationIgnored private var liveName = "camera"
    @ObservationIgnored private let onFrame: (LandmarkFrame) -> Void
    @ObservationIgnored private let onChange: () -> Void
    private static let log = Logger(subsystem: "dev.handy", category: "tracking")

    /// `onFrame` runs the frame through the app's session and applies the events; `onChange` runs
    /// when the camera state or darkness changes, which can happen with no frames arriving.
    init(onFrame: @escaping (LandmarkFrame) -> Void, onChange: @escaping () -> Void) {
        self.onFrame = onFrame
        self.onChange = onChange
    }

    func start() {
        guard capture == nil, permissionTask == nil else { return }
        let deviceID = preferredCameraID
        switch CameraPermission.current {
        case .granted:
            startCapture(deviceID: deviceID)
        case .notDetermined:
            camera = .starting
            permissionTask = Task { [weak self] in
                let granted = await CameraPermission.request() == .granted
                guard let self, self.permissionTask != nil else { return }
                self.permissionTask = nil
                if granted {
                    self.startCapture(deviceID: deviceID)
                } else {
                    self.camera = .permissionDenied
                }
            }
        case .denied, .restricted:
            camera = .permissionDenied
        }
    }

    /// Stops and starts again, picking up a new preferred camera or a camera freed by another app.
    func restart() {
        stop()
        start()
    }

    private func startCapture(deviceID: String?) {
        let capture = CameraCapture()
        self.capture = capture
        camera = .starting
        frameTask = Task { [weak self] in
            for await frame in capture.frames { self?.handle(frame) }
        }
        eventTask = Task { [weak self] in
            for await event in capture.events { self?.handle(event) }
        }
        capture.start(deviceID: deviceID)
    }

    func stop() {
        permissionTask?.cancel()
        permissionTask = nil
        capture?.stop()
        capture = nil
        frameTask?.cancel()
        eventTask?.cancel()
        frameTask = nil
        eventTask = nil
        camera = .off
        debugFrame = nil
        isTooDark = false
        darkness = DarknessMonitor()
    }

    /// Applies a camera event. Internal so handyctl can simulate camera loss.
    func handle(_ event: CameraEvent) {
        switch event {
        case .started(let name):
            liveName = name
            camera = .live(name)
        case .stopped: camera = .off
        case .interrupted(let reason): camera = .paused(reason)
        case .resumed: camera = .live(liveName)
        case .failed(let message): camera = .failed(message)
        }
    }

    /// Applies a brightness reading, as the camera does every frame. Internal so handyctl can simulate darkness.
    func observeBrightness(_ brightness: Double, at t: Double) {
        darkness.update(brightness: brightness, at: t)
        if darkness.isTooDark != isTooDark { isTooDark = darkness.isTooDark }
    }

    private func handle(_ frame: PerceptionFrame) {
        let start = ContinuousClock.now
        onFrame(frame.landmarks)
        let elapsed = start.duration(to: .now)
        pipeline.append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
        inference.append(frame.inferenceMilliseconds)
        if let previous = last { intervals.append((frame.landmarks.t - previous.landmarks.t) * 1000) }
        if let face = frame.landmarks.face {
            lastFace = face
            faceTimes.append(frame.faceMilliseconds)
        }
        frameCount += 1
        last = frame
        observeBrightness(frame.brightness, at: frame.landmarks.t)
        record(frame.landmarks)
    }

    var lastBrightness: Double { last?.brightness ?? 0.5 }
    var lastAspect: Double { last?.aspect ?? 16.0 / 9 }

    /// A camera problem to say plainly in the HUD, or nil.
    var problem: Problem? {
        switch camera {
        case .paused(.inUseByAnotherApp): .cameraInUse
        case .paused(.disconnected): .cameraDisconnected
        case .paused(.unavailable): .noCamera
        case .permissionDenied: .cameraPermissionDenied
        case .failed(let message): .cameraFailed(message)
        case .live: isTooDark ? .tooDark : nil
        case .off, .starting: nil
        }
    }

    func publishDebug(_ features: FrameFeatures?, for landmarks: LandmarkFrame) {
        guard publishesDebugFrames, let features else { return }
        debugFrame = DebugFrame(landmarks: landmarks, features: features, aspect: last?.aspect ?? 16.0 / 9)
    }

    var stats: PerceptionStats? {
        guard frameCount > 0, let last else { return nil }
        return PerceptionStats(
            frames: frameCount, inference: inference.summary.rounded(),
            filterFeaturesEngine: pipeline.summary.rounded(),
            handsInLastFrame: last.landmarks.hands.count, idle: last.idle,
            brightness: (last.brightness * 1000).rounded() / 1000,
            lastFace: lastFace.map { $0.yaw.map { String(format: "%.0f°", $0) } ?? "none" },
            frameInterval: intervals.summary.rounded(), face: faceTimes.summary.rounded())
    }

    // MARK: Recording

    func setRecording(_ on: Bool) throws {
        if on {
            guard recorder == nil else { return }
            let folder = AppPaths.recordings
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
                .replacingOccurrences(of: ":", with: "")
            let url = folder.appending(path: "\(name).lmk")
            recorder = try LandmarkStreamWriter(
                url: url,
                header: .init(source: "vision", meta: ["aspect": String(last?.aspect ?? 16.0 / 9)]))
            recordingOrigin = nil
            recordingURL = url
        } else {
            try recorder?.close()
            recorder = nil
            recordingURL = nil
        }
    }

    private func record(_ landmarks: LandmarkFrame) {
        guard let recorder else { return }
        let origin = recordingOrigin ?? landmarks.t
        recordingOrigin = origin
        var frame = landmarks
        frame.t = landmarks.t - origin
        do {
            try recorder.append(frame)
        } catch {
            Self.log.error("recording failed: \(error.localizedDescription)")
            try? setRecording(false)
        }
    }
}
