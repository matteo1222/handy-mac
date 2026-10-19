import ArgumentParser
import Foundation
import HandyCore
import HandyOutput
import HandyPerception

struct Doctor: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Report build, permission, camera and version info. Exits 1 when a check fails."
    )

    @Flag(help: "Treat warnings as failures.")
    var strict = false

    func run() async throws {
        let report = DoctorReport.current()
        try printJSON(report)
        if report.failed(strict: strict) { throw ExitCode.failure }
    }
}

struct DoctorReport: Codable {
    enum Status: String, Codable { case ok, warn, fail }

    struct Check: Codable {
        let name: String
        let status: Status
        let detail: String
    }

    let version: String
    let os: String
    let arch: String
    let checks: [Check]

    func failed(strict: Bool) -> Bool {
        checks.contains { $0.status == .fail || (strict && $0.status == .warn) }
    }

    static func current() -> DoctorReport {
        let camera = CameraPermission.current
        let cameraStatus: Status =
            switch camera {
            case .granted: .ok
            case .notDetermined: .warn
            case .denied, .restricted: .fail
            }
        let devices = CameraDevices.available()
        let accessibility = AccessibilityPermission.isGranted
        return DoctorReport(
            version: BuildInfo.version,
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            arch: machineArchitecture(),
            checks: [
                Check(name: "camera.permission", status: cameraStatus, detail: camera.rawValue),
                Check(
                    name: "camera.devices", status: devices.isEmpty ? .fail : .ok,
                    detail: devices.isEmpty ? "no video capture device" : devices.map(\.name).joined(separator: ", ")),
                Check(
                    name: "accessibility.permission", status: accessibility ? .ok : .warn,
                    detail: accessibility
                        ? "granted" : "not granted for this process; the app asks at the first click step"),
            ]
        )
    }

    private static func machineArchitecture() -> String {
        #if arch(arm64)
            "arm64"
        #else
            "x86_64"
        #endif
    }
}

func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data + Data("\n".utf8))
}
