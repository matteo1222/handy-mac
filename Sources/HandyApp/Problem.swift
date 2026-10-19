import AppKit
import HandyPerception

/// Something stopping Handy from working, said plainly, with a one-click fix where there is one.
enum Problem: Equatable {
    case cameraInUse
    case cameraDisconnected
    case noCamera
    case cameraPermissionDenied
    case cameraFailed(String)
    case accessibilityNeeded
    case tooDark

    var message: String {
        switch self {
        case .cameraInUse: "Camera in use by another app"
        case .cameraDisconnected: "Camera disconnected"
        case .noCamera: "No camera available"
        case .cameraPermissionDenied: "Camera access is off"
        case .cameraFailed(let detail): "Camera error: \(detail)"
        case .accessibilityNeeded: "Accessibility permission needed"
        case .tooDark: "Too dark to see your hands. Add light"
        }
    }

    var fix: Fix? {
        switch self {
        case .cameraInUse, .cameraFailed: .retryCamera
        case .cameraDisconnected, .noCamera: .useFallbackCamera
        case .cameraPermissionDenied: .openCameraSettings
        case .accessibilityNeeded: .openAccessibilitySettings
        case .tooDark: nil
        }
    }

    enum Fix: Equatable {
        case retryCamera
        case useFallbackCamera
        case openCameraSettings
        case openAccessibilitySettings

        var title: String {
            switch self {
            case .retryCamera: "Retry"
            case .useFallbackCamera: CameraDevices.fallback().map { "Use \($0.name)" } ?? "Retry"
            case .openCameraSettings, .openAccessibilitySettings: "Open Settings"
            }
        }

        /// System Settings pane for permission fixes.
        var settingsURL: URL? {
            switch self {
            case .openCameraSettings:
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
            case .openAccessibilitySettings:
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
            case .retryCamera, .useFallbackCamera: nil
            }
        }
    }
}
