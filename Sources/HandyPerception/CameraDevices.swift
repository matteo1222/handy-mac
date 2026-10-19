import AVFoundation

public struct CameraDevice: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum CameraDevices {
    public static func available() -> [CameraDevice] {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return session.devices.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
    }
}
