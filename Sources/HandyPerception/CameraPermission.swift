import AVFoundation

public enum CameraPermission: String, Sendable, Codable {
    case notDetermined
    case granted
    case denied
    case restricted

    public static var current: CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    public static func request() async -> CameraPermission {
        await AVCaptureDevice.requestAccess(for: .video) ? .granted : current
    }
}
