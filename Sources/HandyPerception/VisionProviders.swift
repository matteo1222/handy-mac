import CoreVideo
import HandyCore
import Vision

/// Backend A: Apple Vision's `VNDetectHumanHandPoseRequest`.
public final class VisionHandPoseProvider: HandPoseProvider {
    public let name = "vision"
    private let request: VNDetectHumanHandPoseRequest

    public init(maximumHandCount: Int = 2) {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = maximumHandCount
    }

    public func hands(in pixelBuffer: CVPixelBuffer) throws -> [HandPose] {
        // Vision's request results are autoreleased; drain them per frame (see CoreMLHandPoseProvider).
        try autoreleasepool { try track(pixelBuffer) }
    }

    private func track(_ pixelBuffer: CVPixelBuffer) throws -> [HandPose] {
        let geometry = ImageGeometry(
            width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
        return (request.results ?? []).compactMap { Self.pose(from: $0, geometry: geometry) }
    }

    public func hands(in image: CGImage) throws -> [HandPose] {
        let geometry = ImageGeometry(width: image.width, height: image.height)
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { Self.pose(from: $0, geometry: geometry) }
    }

    static func pose(from observation: VNHumanHandPoseObservation, geometry: ImageGeometry) -> HandPose? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }
        let joints = HandyCore.Joint.allCases.map { joint -> JointSample? in
            guard let point = points[joint.visionName] else { return nil }
            return JointSample(
                geometry.point(normalizedX: point.location.x, normalizedY: point.location.y),
                confidence: Double(point.confidence))
        }
        // Vision names the hand as it appears in the image. Frames are mirrored before Vision sees them,
        // so a user's right hand looks like a left hand: swap to name the user's own hand (confirmed on a
        // live recording, where the raised right hand came back `.left`).
        let chirality: HandyCore.Chirality = observation.chirality == .left ? .right : .left
        return HandPose(chirality: chirality, joints: joints)
    }
}

/// Face yaw from `VNDetectFaceRectanglesRequest`. Revision 3 reports yaw; if it finds nothing, the
/// default revision gets a try, and a face found without a yaw counts as facing the camera.
public final class VisionFaceProvider: FaceProvider {
    private let withYaw: VNDetectFaceRectanglesRequest
    private let fallback = VNDetectFaceRectanglesRequest()

    public init() {
        withYaw = VNDetectFaceRectanglesRequest()
        withYaw.revision = VNDetectFaceRectanglesRequestRevision3
    }

    public func face(in pixelBuffer: CVPixelBuffer) throws -> FaceSample {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([withYaw])
        if let face = Self.largest(withYaw.results) {
            return FaceSample(yaw: face.yaw.map { $0.doubleValue * 180 / .pi } ?? 0)
        }
        try handler.perform([fallback])
        return FaceSample(yaw: Self.largest(fallback.results).map { _ in 0 })
    }

    private static func largest(_ faces: [VNFaceObservation]?) -> VNFaceObservation? {
        (faces ?? []).max {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        }
    }
}

extension HandyCore.Joint {
    var visionName: VNHumanHandPoseObservation.JointName {
        switch self {
        case .wrist: .wrist
        case .thumbCMC: .thumbCMC
        case .thumbMP: .thumbMP
        case .thumbIP: .thumbIP
        case .thumbTip: .thumbTip
        case .indexMCP: .indexMCP
        case .indexPIP: .indexPIP
        case .indexDIP: .indexDIP
        case .indexTip: .indexTip
        case .middleMCP: .middleMCP
        case .middlePIP: .middlePIP
        case .middleDIP: .middleDIP
        case .middleTip: .middleTip
        case .ringMCP: .ringMCP
        case .ringPIP: .ringPIP
        case .ringDIP: .ringDIP
        case .ringTip: .ringTip
        case .littleMCP: .littleMCP
        case .littlePIP: .littlePIP
        case .littleDIP: .littleDIP
        case .littleTip: .littleTip
        }
    }
}
