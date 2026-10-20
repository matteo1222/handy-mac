import CoreVideo
import Foundation
import HandyCore

/// The port every hand-pose backend implements. Frames arrive already mirrored.
/// Implementations are confined to the capture queue, so they need not be Sendable.
public protocol HandPoseProvider: AnyObject {
    var name: String { get }
    func hands(in pixelBuffer: CVPixelBuffer) throws -> [HandPose]
}

/// The attention port: face yaw from the same frames, run at a lower rate.
public protocol FaceProvider: AnyObject {
    func face(in pixelBuffer: CVPixelBuffer) throws -> FaceSample
}

/// Maps backend coordinates (normalised 0...1, origin bottom-left) into HandyCore points
/// (frame heights, origin top-left).
public struct ImageGeometry: Sendable, Hashable {
    public var aspect: Double

    public init(width: Int, height: Int) {
        aspect = height > 0 ? Double(width) / Double(height) : 16.0 / 9
    }

    public init(aspect: Double) {
        self.aspect = aspect
    }

    public func point(normalizedX x: Double, normalizedY y: Double) -> Point {
        Point(x: x * aspect, y: 1 - y)
    }
}

/// The hand-pose backends, by the name `handyctl` and the `handBackend` default use.
public enum HandBackend: String, Sendable, CaseIterable {
    case vision
    case coreml

    /// The backend named by the `handBackend` user default, Vision when unset or unknown.
    public static var preferred: HandBackend {
        UserDefaults.standard.string(forKey: "handBackend").flatMap(HandBackend.init(rawValue:)) ?? .vision
    }

    /// A fresh provider; Core ML falls back to Vision if its models cannot load.
    public func makeProvider() -> any HandPoseProvider {
        switch self {
        case .vision: VisionHandPoseProvider()
        case .coreml: (try? CoreMLHandPoseProvider()) ?? VisionHandPoseProvider()
        }
    }
}
