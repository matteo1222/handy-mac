@preconcurrency import AVFoundation
import CoreMedia
import HandyCore
import os

/// One processed camera frame, ready for the engine.
public struct PerceptionFrame: Sendable {
    public var landmarks: LandmarkFrame
    public var aspect: Double
    /// Milliseconds spent in the hand-pose backend for this frame.
    public var inferenceMilliseconds: Double
    public var idle: Bool
    /// Mean luma 0...1, sampled for the too-dark check.
    public var brightness: Double
}

public enum CameraEvent: Sendable, Equatable {
    case started(deviceName: String)
    case stopped
    case interrupted(CameraInterruption)
    case failed(String)
}

public enum CameraInterruption: String, Sendable, Codable {
    case inUseByAnotherApp
    case disconnected
    case unavailable
}

/// Runs hand pose (and face, at 5 fps) on the capture queue. Its executor *is* that serial
/// queue, so the sample-buffer callback can enter its isolation synchronously.
actor PerceptionWorker {
    private let queue: DispatchSerialQueue
    private let handProvider: any HandPoseProvider
    private let faceProvider: (any FaceProvider)?
    private var throttle = FrameThrottle()
    private var origin: CMTime?
    private let continuation: AsyncStream<PerceptionFrame>.Continuation
    private static let log = Logger(subsystem: "dev.handy", category: "perception")

    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    init(
        queue: DispatchSerialQueue, hands: sending any HandPoseProvider, face: sending (any FaceProvider)?,
        continuation: AsyncStream<PerceptionFrame>.Continuation
    ) {
        self.queue = queue
        self.handProvider = hands
        self.faceProvider = face
        self.continuation = continuation
    }

    func process(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let origin = self.origin ?? time
        self.origin = origin
        let t = CMTimeGetSeconds(CMTimeSubtract(time, origin))
        guard throttle.shouldProcess(at: t) else { return }

        let start = ContinuousClock.now
        var hands: [HandPose] = []
        do {
            hands = try handProvider.hands(in: pixelBuffer)
        } catch {
            Self.log.error("hand pose failed: \(error.localizedDescription)")
        }
        let inference = start.duration(to: .now)
        throttle.record(handsSeen: !hands.isEmpty, at: t)

        var face: FaceSample?
        if let faceProvider, throttle.shouldDetectFace(at: t) {
            face = try? faceProvider.face(in: pixelBuffer)
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        continuation.yield(
            PerceptionFrame(
                landmarks: LandmarkFrame(t: t, hands: hands, face: face),
                aspect: Double(width) / Double(max(height, 1)),
                inferenceMilliseconds: Double(inference.components.attoseconds) / 1e15
                    + Double(inference.components.seconds) * 1000,
                idle: throttle.isIdle(at: t),
                brightness: Self.meanLuma(pixelBuffer)))
    }

    /// Samples the Y plane of a bi-planar YUV buffer on a coarse grid.
    static func meanLuma(_ buffer: CVPixelBuffer) -> Double {
        guard CVPixelBufferGetPlaneCount(buffer) >= 1 else { return 0.5 }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return 0.5 }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var total = 0
        var count = 0
        for y in Swift.stride(from: 0, to: height, by: 24) {
            for x in Swift.stride(from: 0, to: width, by: 24) {
                total += Int(bytes[y * stride + x])
                count += 1
            }
        }
        return count > 0 ? Double(total) / Double(count) / 255 : 0.5
    }
}

/// Bridges AVFoundation's delegate callback into the worker's isolation.
private final class SampleBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    let worker: PerceptionWorker

    init(worker: PerceptionWorker) {
        self.worker = worker
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        // AVFoundation calls this on the worker's own serial queue and keeps the buffer alive for
        // the call, so handing it to the worker synchronously cannot race.
        nonisolated(unsafe) let buffer = sampleBuffer
        worker.assumeIsolated { $0.process(buffer) }
    }
}

/// The live camera: 1280×720 at 30 fps (60 when offered), late frames dropped, mirrored.
@MainActor
public final class CameraCapture {
    public let frames: AsyncStream<PerceptionFrame>
    public let events: AsyncStream<CameraEvent>
    public private(set) var isRunning = false

    private let session = AVCaptureSession()
    private let queue = DispatchSerialQueue(label: "dev.handy.capture", qos: .userInteractive)
    private let frameContinuation: AsyncStream<PerceptionFrame>.Continuation
    private let eventContinuation: AsyncStream<CameraEvent>.Continuation
    private let delegate: SampleBufferDelegate
    private var observers: [any NSObjectProtocol] = []

    public init(
        hands: sending any HandPoseProvider = VisionHandPoseProvider(),
        face: sending (any FaceProvider)? = VisionFaceProvider()
    ) {
        (frames, frameContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(2))
        (events, eventContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
        delegate = SampleBufferDelegate(
            worker: PerceptionWorker(queue: queue, hands: hands, face: face, continuation: frameContinuation))
        observeSession()
    }

    /// Starts the camera with the given device, or the system default when nil or missing.
    public func start(deviceID: String?) {
        guard !isRunning else { return }
        guard let device = deviceID.flatMap(AVCaptureDevice.init(uniqueID:)) ?? AVCaptureDevice.default(for: .video)
        else {
            eventContinuation.yield(.interrupted(.unavailable))
            return
        }
        do {
            try configure(device)
        } catch {
            eventContinuation.yield(.failed(error.localizedDescription))
            return
        }
        isRunning = true
        let session = session
        let name = device.localizedName
        let events = eventContinuation
        queue.async {
            session.startRunning()
            events.yield(session.isRunning ? .started(deviceName: name) : .interrupted(.inUseByAnotherApp))
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        let session = session
        let events = eventContinuation
        queue.async {
            session.stopRunning()
            events.yield(.stopped)
        }
    }

    private func configure(_ device: AVCaptureDevice) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CaptureError.cannotAddInput }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(delegate, queue: queue)
        guard session.canAddOutput(output) else { throw CaptureError.cannotAddOutput }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        try Self.preferHighFrameRate(device)
    }

    private static func preferHighFrameRate(_ device: AVCaptureDevice) throws {
        let supports60 = device.activeFormat.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 60 }
        let fps: Int32 = supports60 ? 60 : 30
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= Double(fps) })
        else { return }
        try device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: fps)
        device.unlockForConfiguration()
    }

    private func observeSession() {
        let center = NotificationCenter.default
        let events = eventContinuation
        observers.append(
            center.addObserver(forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil) {
                _ in
                // macOS gives no interruption reason; another app taking the camera is the usual cause.
                events.yield(.interrupted(.inUseByAnotherApp))
            })
        observers.append(
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil) {
                note in
                let error = note.userInfo?[AVCaptureSessionErrorKey] as? Error
                events.yield(.failed(error?.localizedDescription ?? "camera error"))
            })
        observers.append(
            center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: nil) { _ in
                events.yield(.interrupted(.disconnected))
            })
    }

    enum CaptureError: Error {
        case cannotAddInput
        case cannotAddOutput
    }
}
