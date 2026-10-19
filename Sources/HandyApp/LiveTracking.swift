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
        case failed(String)

        var description: String {
            switch self {
            case .off: "off"
            case .starting: "starting"
            case .live(let name): "live: \(name)"
            case .paused(let reason): "paused: \(reason.rawValue)"
            case .failed(let message): "failed: \(message)"
            }
        }
    }

    private(set) var camera: CameraState = .off
    private(set) var recordingURL: URL?
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
    @ObservationIgnored private var frameCount = 0
    @ObservationIgnored private var last: PerceptionFrame?
    @ObservationIgnored private let onFrame: (LandmarkFrame) -> Void
    private static let log = Logger(subsystem: "dev.handy", category: "tracking")

    /// `onFrame` runs the frame through the app's session and applies the events.
    init(onFrame: @escaping (LandmarkFrame) -> Void) {
        self.onFrame = onFrame
    }

    func start(deviceID: String? = nil) {
        guard capture == nil, permissionTask == nil else { return }
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
                    self.camera = .failed("camera permission denied")
                }
            }
        case .denied, .restricted:
            camera = .failed("camera permission denied")
        }
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
    }

    private func handle(_ event: CameraEvent) {
        switch event {
        case .started(let name): camera = .live(name)
        case .stopped: camera = .off
        case .interrupted(let reason): camera = .paused(reason)
        case .failed(let message): camera = .failed(message)
        }
    }

    private func handle(_ frame: PerceptionFrame) {
        let start = ContinuousClock.now
        onFrame(frame.landmarks)
        let elapsed = start.duration(to: .now)
        pipeline.append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
        inference.append(frame.inferenceMilliseconds)
        frameCount += 1
        last = frame
        record(frame.landmarks)
    }

    /// A camera problem to say plainly in the HUD, or nil.
    var problem: String? {
        switch camera {
        case .paused(.inUseByAnotherApp): "Camera in use by another app"
        case .paused(.disconnected): "Camera disconnected"
        case .paused(.unavailable): "No camera available"
        case .failed(let message): message.prefix(1).uppercased() + message.dropFirst()
        case .off, .starting, .live: nil
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
            brightness: (last.brightness * 1000).rounded() / 1000)
    }

    // MARK: Recording

    func setRecording(_ on: Bool) throws {
        if on {
            guard recorder == nil else { return }
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appending(path: "Handy/Recordings")
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
