import AVFoundation

public struct CameraDevice: Sendable, Hashable, Codable, Identifiable {
    public enum Kind: String, Sendable, Codable {
        case builtIn
        case external
        case continuity
    }

    public let id: String
    public let name: String
    public let kind: Kind

    public init(id: String, name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

public enum CameraDevices {
    public static func available() -> [CameraDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return session.devices.map { device in
            let kind: CameraDevice.Kind =
                switch device.deviceType {
                case .builtInWideAngleCamera: .builtIn
                case .continuityCamera: .continuity
                default: .external
                }
            return CameraDevice(id: device.uniqueID, name: device.localizedName, kind: kind)
        }
    }

    /// The built-in camera, or the first camera available.
    public static func fallback() -> CameraDevice? {
        let all = available()
        return all.first { $0.kind == .builtIn } ?? all.first
    }
}
