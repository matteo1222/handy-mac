import CoreML
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

    /// The default backend: Core ML is the one inside the 10 ms inference budget (decision-3).
    public static let standard = HandBackend.coreml

    /// The backend named by the `handBackend` user default, the standard one when unset or unknown.
    public static var preferred: HandBackend {
        UserDefaults.standard.string(forKey: "handBackend").flatMap(HandBackend.init(rawValue:)) ?? standard
    }

    /// A fresh provider; Core ML falls back to Vision if its models cannot load. `live` is for the
    /// running camera: see `liveComputeUnits`.
    public func makeProvider(live: Bool = false) -> any HandPoseProvider {
        switch self {
        case .vision: VisionHandPoseProvider()
        case .coreml:
            (try? CoreMLHandPoseProvider(computeUnits: live ? Self.liveComputeUnits : .all, backgroundDetection: live))
                ?? VisionHandPoseProvider()
        }
    }

    /// Core ML on the live camera skips the Neural Engine. While a camera streams, the system's
    /// camera pipeline keeps the Neural Engine busy for ~20 ms after each frame arrives, just when
    /// Handy wants it: on an M3, in-app Core ML took p50 20 / p95 23 ms on `.all` against 12.6 / 13.3
    /// on `.cpuAndGPU` (release build, 30 fps, no hand). Offline, with no camera, the Neural Engine
    /// is fastest, so video and benches keep `.all`.
    public static let liveComputeUnits = MLComputeUnits.cpuAndGPU
}
