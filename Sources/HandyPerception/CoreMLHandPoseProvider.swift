import CoreGraphics
import CoreImage
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

    struct Detection {
        var region: Region
        var score: Double
        var box: CGRect
    }

    static let side = 256
    private let detector: MLModel
    private let landmarker: MLModel
    private let maximumHandCount: Int
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var input: CVPixelBuffer?
    private var tracked: [Region] = []
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

    public init(maximumHandCount: Int = 2, computeUnits: MLComputeUnits = .all) throws {
        let configuration = MLModelConfiguration()
        configuration.computeUnits = computeUnits
        detector = try MLModel(contentsOf: try Self.modelURL("HandPalmDetector"), configuration: configuration)
        landmarker = try MLModel(contentsOf: try Self.modelURL("HandLandmarker"), configuration: configuration)
        self.maximumHandCount = maximumHandCount
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
    }

    public func hands(in pixelBuffer: CVPixelBuffer) throws -> [HandPose] {
        // Core ML and Core Image hand back autoreleased buffers backed by IOSurfaces. A caller that
        // loops without draining a pool (a long video) runs the Neural Engine out of surfaces.
        try autoreleasepool { try track(pixelBuffer) }
    }

    private func track(_ pixelBuffer: CVPixelBuffer) throws -> [HandPose] {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let frame = CIImage(cvPixelBuffer: pixelBuffer)
        framesSinceDetection += 1
        if tracked.isEmpty || (tracked.count < maximumHandCount && framesSinceDetection >= redetectInterval) {
            framesSinceDetection = 0
            for detection in try detect(frame, width: width, height: height) where tracked.count < maximumHandCount {
                let overlaps = tracked.contains { Self.iou(Self.bounds($0), detection.box) > 0.3 }
                if !overlaps { tracked.append(detection.region) }
            }
        }
        var poses: [HandPose] = []
        var next: [Region] = []
        for region in tracked {
            guard let (pose, pixels) = try landmarks(frame, in: region, width: width, height: height) else { continue }
            let following = Self.region(following: pixels)
            // Two tracks that converge on one hand keep only the first.
            if next.contains(where: { Self.iou(Self.bounds($0), Self.bounds(following)) > 0.5 }) { continue }
            poses.append(pose)
            next.append(following)
        }
        tracked = next
        return poses
    }

    // MARK: - Palm detection

    func detect(_ frame: CIImage, width: Int, height: Int) throws -> [Detection] {
        // Letterbox the frame into the square input, like MediaPipe's resize-and-pad.
        let scale = Double(Self.side) / Double(max(width, height))
        let padX = (Double(Self.side) - Double(width) * scale) / 2
        let padY = (Double(Self.side) - Double(height) * scale) / 2
        let placed = frame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: padX, y: padY))
        let output = try predict(detector, placed, key: "detections")
        // Read the score column first and decode only the rows that pass: converting all 2944 × 19
        // values every frame cost more than the model itself, most of all in debug builds.
        let rows = ModelRows(output)
        var candidates: [Detection] = []
        for row in 0..<rows.count {
            let score = Double(rows[row, rows.columns - 1])
            guard score >= 0.5 else { continue }
            func value(_ column: Int) -> Float { rows[row, column] }
            // Normalised square coordinates (origin top-left) to frame pixels.
            func pixel(_ x: Float, _ y: Float) -> CGPoint {
                CGPoint(
                    x: (Double(x) * Double(Self.side) - padX) / scale, y: (Double(y) * Double(Self.side) - padY) / scale
                )
            }
            let topLeft = pixel(value(1), value(0))
            let bottomRight = pixel(value(3), value(2))
            let box = CGRect(
                x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)
            let wrist = pixel(value(4), value(5))
            let middle = pixel(value(8), value(9))
            // MediaPipe's palm-to-hand rect: shift half a box toward the fingers, grow 2.6×.
            let rotation = atan2(wrist.y - middle.y, wrist.x - middle.x) - .pi / 2
            let size = box.width * 2.6
            let shift = CGPoint(x: -sin(rotation) * -0.5 * box.width, y: cos(rotation) * -0.5 * box.width)
            let center = CGPoint(x: box.midX + shift.x, y: box.midY + shift.y)
            candidates.append(
                Detection(region: Region(center: center, size: size, rotation: rotation), score: score, box: box))
        }
        // Non-maximum suppression.
        var kept: [Detection] = []
        for candidate in candidates.sorted(by: { $0.score > $1.score })
        where !kept.contains(where: { Self.iou($0.box, candidate.box) > 0.3 }) {
            kept.append(candidate)
        }
        return kept
    }

    // MARK: - Landmarks

    func landmarks(_ frame: CIImage, in region: Region, width: Int, height: Int) throws -> (HandPose, [CGPoint])? {
        // Core Image is y-up; regions are y-down. Flip into and out of the crop.
        let toFrame = region.cropToFrame
        let flipFrame = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(height))
        let flipCrop = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: Double(Self.side))
        let frameToCropCI = flipFrame.concatenating(toFrame.inverted()).concatenating(flipCrop)
        let output = try predict(landmarker, frame.transformed(by: frameToCropCI), key: "landmarks")
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

    private func predict(_ model: MLModel, _ image: CIImage, key: String) throws -> MLMultiArray {
        let buffer = try inputBuffer()
        let square = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        let background = CIImage(color: .black).cropped(to: square)
        context.render(image.cropped(to: square).composited(over: background), to: buffer)
        let features = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)])
        guard let array = try model.prediction(from: features).featureValue(for: key)?.multiArrayValue else {
            throw Failure.missingModel(key)
        }
        return array
    }

    private func inputBuffer() throws -> CVPixelBuffer {
        if let input { return input }
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, Self.side, Self.side, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        guard let buffer else { throw Failure.missingModel("input buffer") }
        input = buffer
        return buffer
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
