import CoreGraphics
import CoreML
import CoreVideo
import Foundation
import HandyCore

/// Backend B: MediaPipe's palm detector and hand landmarker on Core ML, with frame-to-frame ROI
/// tracking. The palm detector runs only to find a hand; once found, each frame crops around the
/// hand from the previous frame's landmarks, so the steady state is one small landmark model per hand.
///
/// Both models take 256×256 RGB. Models are converted by `scripts/convert-hand-models.sh`.
public final class CoreMLHandPoseProvider: HandPoseProvider {
    public let name = "coreml"

    /// An oriented square in frame pixels (origin top-left), as MediaPipe's rects.
    struct Region: Equatable {
        var center: CGPoint
        var size: Double
        /// Radians; 0 when the hand points up.
        var rotation: Double

        /// Maps crop pixels (0...256, origin top-left) to frame pixels.
        var cropToFrame: CGAffineTransform {
            let scale = size / Double(CoreMLHandPoseProvider.side)
            return CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: rotation)
                .scaledBy(x: scale, y: scale)
                .translatedBy(x: -Double(CoreMLHandPoseProvider.side) / 2, y: -Double(CoreMLHandPoseProvider.side) / 2)
        }
    }

    /// A hand being followed: where to crop next, and the area it covered (its landmarks' bounds,
    /// or the palm box for a hand just detected).
    struct Track {
        var region: Region
        var extent: CGRect
    }

    struct Detection {
        var region: Region
        var score: Double
        var box: CGRect
    }

    static let side = 256
    private let palms: PalmDetector
    private let landmarker: MLModel
    private let landmarkInput: CropRenderer
    private let maximumHandCount: Int
    private let backgroundDetection: Bool
    private var tracked: [Track] = []
    /// Landmark-model runs so far, for tests: one per tracked hand per frame.
    private(set) var landmarkRuns = 0
    private var framesSinceDetection = 0
    /// Frames between palm-detector runs while fewer hands than the maximum are tracked.
    private let redetectInterval = 10

    public enum Failure: Error, CustomStringConvertible {
        case missingModel(String)
        public var description: String {
            switch self {
            case .missingModel(let name): "the \(name) Core ML model is not in the app bundle"
            }
        }
    }

    /// With `backgroundDetection`, the palm detector runs on its own queue after a frame's landmarks,
    /// and the hands it finds join on the next frame: a frame costs only the landmark model, and a
    /// hand takes one frame longer to pick up. For the live camera; offline callers keep each frame's
    /// result a function of the frames so far.
    public init(
        maximumHandCount: Int = 2, computeUnits: MLComputeUnits = .all, backgroundDetection: Bool = false
    ) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        palms = try PalmDetector(
            model: try MLModel(contentsOf: try Self.modelURL("HandPalmDetector"), configuration: configuration))
        landmarker = try MLModel(contentsOf: try Self.modelURL("HandLandmarker"), configuration: configuration)
        landmarkInput = try CropRenderer(side: Self.side)
        self.maximumHandCount = maximumHandCount
        self.backgroundDetection = backgroundDetection
    }

    static func modelURL(_ name: String) throws -> URL {
        // In the app the SwiftPM resource bundle sits in Contents/Resources; in tests and handyctl
        // it sits next to the executable, where `Bundle.module` finds it.
        let bundleName = "Handy_HandyPerception.bundle"
        let candidates = [Bundle.main.resourceURL, Bundle.main.executableURL?.deletingLastPathComponent()]
            .compactMap { $0?.appending(path: bundleName) }
        let bundle =
            candidates.first { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
            .flatMap(Bundle.init(url:)) ?? Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: "mlmodelc", subdirectory: "Models") else {
            throw Failure.missingModel(name)
        }
        return url
    }

    public func reset() {
        tracked = []
        framesSinceDetection = 0
        _ = palms.takeFound()
    }

    public func hands(in pixelBuffer: CVPixelBuffer) throws -> [HandPose] {
        // Core ML hands back autoreleased buffers backed by IOSurfaces. A caller that loops without
        // draining a pool (a long video) runs the Neural Engine out of surfaces.
        try autoreleasepool { try track(pixelBuffer) }
    }

    private func track(_ pixelBuffer: CVPixelBuffer) throws -> [HandPose] {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        framesSinceDetection += 1
        if backgroundDetection {
            adopt(palms.takeFound())
        } else if needsDetection {
            framesSinceDetection = 0
            adopt(try palms.detect(pixelBuffer))
        }
        var poses: [HandPose] = []
        var next: [Track] = []
        for track in tracked {
            guard let (pose, pixels) = try landmarks(pixelBuffer, in: track.region, width: width, height: height)
            else { continue }
            let following = Self.region(following: pixels)
            // Two tracks that converge on one hand keep only the first.
            if next.contains(where: { Self.iou(Self.bounds($0.region), Self.bounds(following)) > 0.5 }) { continue }
            poses.append(pose)
            next.append(Track(region: following, extent: Self.extent(of: pixels)))
        }
        tracked = next
        // After this frame's landmarks, so the search runs in the gap before the next frame.
        if backgroundDetection, needsDetection {
            framesSinceDetection = 0
            palms.detectInBackground(pixelBuffer)
        }
        return poses
    }

    /// No hand tracked, or room for another and time to look for it.
    private var needsDetection: Bool {
        tracked.isEmpty || (tracked.count < maximumHandCount && framesSinceDetection >= redetectInterval)
    }

    /// Starts tracking detected palms that are not already tracked, up to the maximum. A palm whose
    /// centre lies on a tracked hand (its extent, padded a quarter each way for a search that ran a
    /// frame earlier) is that hand. (Comparing the palm box with the tracked crop
    /// square never matched: the square is 2.6 times the palm's width, so every search re-added the
    /// tracked hand and the next frame ran the landmark model twice.)
    private func adopt(_ detections: [Detection]) {
        for detection in detections where tracked.count < maximumHandCount {
            let palm = CGPoint(x: detection.box.midX, y: detection.box.midY)
            let onTracked = tracked.contains {
                $0.extent.insetBy(dx: -$0.extent.width / 4, dy: -$0.extent.height / 4).contains(palm)
            }
            if !onTracked {
                tracked.append(Track(region: detection.region, extent: detection.box))
            }
        }
    }

    static func extent(of pixels: [CGPoint]) -> CGRect {
        let xs = pixels.map(\.x)
        let ys = pixels.map(\.y)
        let (minX, minY) = (xs.min() ?? 0, ys.min() ?? 0)
        return CGRect(x: minX, y: minY, width: (xs.max() ?? 0) - minX, height: (ys.max() ?? 0) - minY)
    }

    // MARK: - Landmarks

    func landmarks(_ frame: CVPixelBuffer, in region: Region, width: Int, height: Int) throws -> (HandPose, [CGPoint])?
    {
        let toFrame = region.cropToFrame
        landmarkRuns += 1
        let output = try Self.predict(landmarker, landmarkInput, frame, cropToFrame: toFrame, key: "landmarks")
        let values = Self.floats(output)
        let presence = Double(values[0])
        guard presence >= 0.5 else { return nil }
        let handedness = Double(values[1])
        let geometry = ImageGeometry(width: width, height: height)
        var pixels: [CGPoint] = []
        let joints = (0..<21).map { index -> JointSample? in
            let crop = CGPoint(
                x: Double(values[2 + index * 3]) * Double(Self.side),
                y: Double(values[3 + index * 3]) * Double(Self.side))
            let pixel = crop.applying(toFrame)
            pixels.append(pixel)
            return JointSample(
                geometry.point(
                    normalizedX: Double(pixel.x) / Double(width), normalizedY: 1 - Double(pixel.y) / Double(height)),
                confidence: presence)
        }
        // On our mirrored frames the score reads high for the user's left hand: read the other way, the
        // labels disagreed with Vision's (checked against a live hand) on 85% of the hands both found
        // in the same video frames.
        let chirality: Chirality = handedness >= 0.5 ? .left : .right
        return (HandPose(chirality: chirality, joints: Self.ordered(joints)), pixels)
    }

    /// MediaPipe and HandyCore number the 21 joints the same way (wrist, thumb CMC to tip, then each
    /// finger MCP to tip), so the order carries over.
    static func ordered(_ joints: [JointSample?]) -> [JointSample?] { joints }

    /// MediaPipe's landmarks-to-rect: rotation from wrist to middle knuckle, the hand's extent in that
    /// frame, doubled, nudged toward the fingers.
    static func region(following pixels: [CGPoint]) -> Region {
        let wrist = pixels[Joint.wrist.rawValue]
        let middle = pixels[Joint.middleMCP.rawValue]
        let rotation = atan2(wrist.y - middle.y, wrist.x - middle.x) - .pi / 2
        let unrotate = CGAffineTransform(rotationAngle: -rotation)
        let local = pixels.map { $0.applying(unrotate) }
        let xs = local.map(\.x)
        let ys = local.map(\.y)
        let (minX, maxX, minY, maxY) = (xs.min() ?? 0, xs.max() ?? 0, ys.min() ?? 0, ys.max() ?? 0)
        let size: Double = max(maxX - minX, maxY - minY) * 2
        let localCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2 - 0.1 * size)
        let center = localCenter.applying(CGAffineTransform(rotationAngle: rotation))
        return Region(center: center, size: size, rotation: rotation)
    }

    // MARK: - Plumbing

    /// Renders the crop into `input` and runs the model on it.
    static func predict(
        _ model: MLModel, _ input: CropRenderer, _ frame: CVPixelBuffer, cropToFrame: CGAffineTransform, key: String
    ) throws -> MLMultiArray {
        try input.render(frame, cropToFrame: cropToFrame)
        let features = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: input.output)])
        guard let array = try model.prediction(from: features).featureValue(for: key)?.multiArrayValue else {
            throw Failure.missingModel(key)
        }
        return array
    }

    /// The array's values in row-major order. Core ML may pad rows (fp16 outputs from the Neural
    /// Engine often are), so this walks the strides instead of reading the buffer straight through.
    static func floats(_ array: MLMultiArray) -> [Float] {
        let shape = array.shape.map(\.intValue)
        let strides = array.strides.map(\.intValue)
        let count = shape.reduce(1, *)
        let span = zip(shape, strides).map { ($0 - 1) * $1 }.reduce(0, +) + 1
        let read: (Int) -> Float
        switch array.dataType {
        case .float16:
            let pointer = array.dataPointer.bindMemory(to: UInt16.self, capacity: span)
            read = { Float(Float16(bitPattern: pointer[$0])) }
        case .float32:
            let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: span)
            read = { pointer[$0] }
        default:
            return (0..<count).map { array[$0].floatValue }
        }
        var values = [Float](repeating: 0, count: count)
        for flat in 0..<count {
            var remainder = flat
            var offset = 0
            for axis in shape.indices.reversed() {
                offset += remainder % shape[axis] * strides[axis]
                remainder /= shape[axis]
            }
            values[flat] = read(offset)
        }
        return values
    }

    static func bounds(_ region: Region) -> CGRect {
        CGRect(
            x: region.center.x - region.size / 2, y: region.center.y - region.size / 2, width: region.size,
            height: region.size)
    }

    static func iou(_ a: CGRect, _ b: CGRect) -> Double {
        let overlap = a.intersection(b)
        guard !overlap.isNull else { return 0 }
        let shared = overlap.width * overlap.height
        return shared / (a.width * a.height + b.width * b.height - shared)
    }
}

/// Row and column access into a 2-D model output without copying it, honouring its strides.
struct ModelRows {
    let count: Int
    let columns: Int
    private let rowStride: Int
    private let columnStride: Int
    private let read: (Int) -> Float

    init(_ array: MLMultiArray) {
        count = array.shape[0].intValue
        columns = array.shape[1].intValue
        rowStride = array.strides[0].intValue
        columnStride = array.strides[1].intValue
        let span = (count - 1) * rowStride + (columns - 1) * columnStride + 1
        switch array.dataType {
        case .float16:
            let pointer = array.dataPointer.bindMemory(to: UInt16.self, capacity: span)
            read = { Float(Float16(bitPattern: pointer[$0])) }
        case .float32:
            let pointer = array.dataPointer.bindMemory(to: Float.self, capacity: span)
            read = { pointer[$0] }
        default:
            let columns = columns
            read = { array[[NSNumber(value: $0 / columns), NSNumber(value: $0 % columns)]].floatValue }
        }
    }

    subscript(row: Int, column: Int) -> Float {
        read(row * rowStride + column * columnStride)
    }
}
