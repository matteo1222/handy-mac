import ArgumentParser
import CoreGraphics
import Foundation

struct Windows: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List Handy's on-screen windows as the window server sees them, including whether each is "
            + "excluded from screen capture (sharingState 0). Needs no Screen Recording permission.")

    func run() throws {
        let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let mine = all.filter { $0[kCGWindowOwnerName as String] as? String == "Handy" }.map { info in
            let bounds = info[kCGWindowBounds as String] as? [String: Double] ?? [:]
            let sharing = info[kCGWindowSharingState as String] as? Int ?? -1
            return WindowInfo(
                number: info[kCGWindowNumber as String] as? Int ?? 0,
                layer: info[kCGWindowLayer as String] as? Int ?? 0,
                bounds: [bounds["X"] ?? 0, bounds["Y"] ?? 0, bounds["Width"] ?? 0, bounds["Height"] ?? 0],
                sharingState: sharing,
                excludedFromCapture: sharing == 0)
        }
        try printJSON(mine)
    }
}

struct WindowInfo: Codable {
    let number: Int
    let layer: Int
    let bounds: [Double]
    let sharingState: Int
    let excludedFromCapture: Bool
}
