@preconcurrency import AVFoundation
import CoreImage
import CoreVideo
import HandyCore

/// Turns a video file into landmark frames with the same providers the live camera uses, so real
/// footage can be replayed end to end without a person in front of the camera.
public enum VideoLandmarks {
    public struct Options: Sendable {
        /// Mirror frames like the live camera does. Off for selfie footage that is already mirrored.
        public var mirror = true
        /// Process at most this many frames per second (the source may be faster).
        public var fps = 30.0
        /// Face yaw every this many seconds (the live detector runs at 5 fps).
        public var faceInterval = 0.2
        public var backend = HandBackend.vision

        public init(mirror: Bool = true, fps: Double = 30, backend: HandBackend = .vision) {
            self.mirror = mirror
            self.fps = fps
            self.backend = backend
        }
    }

    public struct Output: Sendable {
        public var frames: [LandmarkFrame]
        public var aspect: Double
        public var inferenceMilliseconds: [Double]
    }

    public enum Failure: Error, CustomStringConvertible {
        case noVideoTrack
        case readerFailed(String)

        public var description: String {
            switch self {
            case .noVideoTrack: "the file has no video track"
            case .readerFailed(let message): "could not read the video: \(message)"
            }
        }
    }

    public static func process(_ url: URL, options: Options = Options()) async throws -> Output {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw Failure.noVideoTrack }
        let transform = try await track.load(.preferredTransform)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        guard reader.startReading() else { throw Failure.readerFailed(reader.error?.localizedDescription ?? "unknown") }

        let hands = options.backend.makeProvider()
        let faces = VisionFaceProvider()
        let context = CIContext()
        var frames: [LandmarkFrame] = []
        var timings: [Double] = []
        var aspect = 16.0 / 9
        var origin: Double?
        var lastKept = -Double.infinity
        var lastFace = -Double.infinity
        let clock = ContinuousClock()

        while let sample = output.copyNextSampleBuffer() {
            guard let source = CMSampleBufferGetImageBuffer(sample) else { continue }
            let time = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
            let start = origin ?? time
            origin = start
            let t = time - start
            guard t - lastKept >= 1 / options.fps - 1e-4 else { continue }
            lastKept = t
            guard let buffer = upright(source, transform: transform, mirror: options.mirror, context: context) else {
                continue
            }
            aspect = Double(CVPixelBufferGetWidth(buffer)) / Double(max(CVPixelBufferGetHeight(buffer), 1))
            var poses: [HandPose] = []
            let elapsed = try clock.measure { poses = try hands.hands(in: buffer) }
            timings.append(Double(elapsed.components.attoseconds) / 1e15 + Double(elapsed.components.seconds) * 1000)
            var face: FaceSample?
            if t - lastFace >= options.faceInterval - 1e-4 {
                lastFace = t
                face = try? faces.face(in: buffer)
            }
            frames.append(LandmarkFrame(t: (t * 1_000_000).rounded() / 1_000_000, hands: poses, face: face))
        }
        if reader.status == .failed { throw Failure.readerFailed(reader.error?.localizedDescription ?? "unknown") }
        return Output(frames: frames, aspect: aspect, inferenceMilliseconds: timings)
    }

    /// Applies the track's orientation (phone videos are often stored rotated) and the mirror.
    static func upright(
        _ buffer: CVPixelBuffer, transform: CGAffineTransform, mirror: Bool, context: CIContext
    ) -> CVPixelBuffer? {
        var image = CIImage(cvPixelBuffer: buffer).transformed(by: transform)
        if mirror { image = image.transformed(by: CGAffineTransform(scaleX: -1, y: 1)) }
        image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        var out: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &out)
        guard let out else { return nil }
        context.render(image, to: out)
        return out
    }
}
