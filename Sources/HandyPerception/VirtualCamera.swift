import CoreGraphics
import CoreVideo
import Foundation
import HandyCore

/// Runs a hand tracker over drawn frames as the live camera would (mirrored, one frame at a time) and
/// scores it against the joints the frames were drawn from. The drawing is the caller's (see
/// `HandRenderer`); this is the tracker half of a virtual camera.
public struct VirtualCamera {
    public struct Frame {
        public var t: Double
        /// The frame as the camera sees it, unmirrored.
        public var image: CGImage
        /// The hands the frame was drawn from.
        public var truth: [HandPose]
        /// Their hand length (wrist to middle knuckle), for scoring in hand lengths.
        public var handLength: Double
        public var face: FaceSample?

        public init(t: Double, image: CGImage, truth: [HandPose], handLength: Double, face: FaceSample?) {
            self.t = t
            self.image = image
            self.truth = truth
            self.handLength = handLength
            self.face = face
        }
    }

    /// What the tracker saw, and how well.
    public struct Result {
        public var frames: [LandmarkFrame]
        /// Tracked hands matched to a drawn hand, per drawn hand per frame.
        public var handFoundRate: Double
        /// Each matched hand's mean joint distance from the drawn joints, in hand lengths.
        public var jointErrors: [Double]
    }

    public var provider: any HandPoseProvider
    /// A drawn hand does not show trackers which side faces them as a real one does, so by default
    /// each tracked hand takes the drawn hand's chirality.
    public var keepsTrackerChirality = false

    public init(provider: any HandPoseProvider, keepsTrackerChirality: Bool = false) {
        self.provider = provider
        self.keepsTrackerChirality = keepsTrackerChirality
    }

    public func track(_ frames: some Sequence<Frame>) throws -> Result {
        var tracked: [LandmarkFrame] = []
        var found = 0
        var total = 0
        var errors: [Double] = []
        for frame in frames {
            // One pool per frame: each frame allocates IOSurface-backed buffers that would otherwise
            // pile up until the frameworks fail to allocate (OSStatus -12905).
            var hands = try autoreleasepool { try provider.hands(in: try Self.mirroredBuffer(frame.image)) }
            total += frame.truth.count
            for i in hands.indices {
                guard let nearest = Self.nearest(to: hands[i], in: frame.truth) else { continue }
                found += 1
                if !keepsTrackerChirality { hands[i] = HandPose(chirality: nearest.chirality, joints: hands[i].joints) }
                if let error = Self.meanError(hands[i], nearest, scale: frame.handLength) { errors.append(error) }
            }
            tracked.append(LandmarkFrame(t: frame.t, hands: hands, face: frame.face))
        }
        return Result(
            frames: tracked, handFoundRate: total > 0 ? Double(found) / Double(total) : 0, jointErrors: errors)
    }

    static func nearest(to hand: HandPose, in truth: [HandPose]) -> HandPose? {
        guard let wrist = hand[.wrist]?.point ?? hand[.middleMCP]?.point else { return nil }
        return truth.min { a, b in
            (a[.wrist]?.point.distance(to: wrist) ?? .infinity) < (b[.wrist]?.point.distance(to: wrist) ?? .infinity)
        }
    }

    static func meanError(_ hand: HandPose, _ truth: HandPose, scale: Double) -> Double? {
        let distances = Joint.allCases.compactMap { joint -> Double? in
            guard let a = hand[joint]?.point, let b = truth[joint]?.point else { return nil }
            return a.distance(to: b)
        }
        guard !distances.isEmpty else { return nil }
        return distances.reduce(0, +) / Double(distances.count) / scale
    }

    public enum Failure: Error {
        case cannotDraw
    }

    /// The frame flipped horizontally into a BGRA buffer, as the live camera path delivers it.
    public static func mirroredBuffer(_ image: CGImage) throws -> CVPixelBuffer {
        var out: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, image.width, image.height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &out)
        guard let buffer = out else { throw Failure.cannotDraw }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer), width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { throw Failure.cannotDraw }
        context.translateBy(x: CGFloat(image.width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return buffer
    }
}
