import Foundation

/// Modules HandyCore must never import. HandyCore stays pure and deterministic, so every
/// platform framework that touches the camera, the screen or the input stream is banned.
let bannedModules: Set<String> = [
    "AppKit", "AVFoundation", "Vision", "Cocoa", "SwiftUI", "CoreGraphics",
    "ApplicationServices", "Carbon", "CoreML", "CoreMedia", "CoreVideo", "Dispatch",
]

struct Violation: Equatable {
    let line: Int
    let module: String
}

func violations(in source: String) -> [Violation] {
    var found: [Violation] = []
    for (index, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        guard let module = importedModule(String(line)), bannedModules.contains(module) else { continue }
        found.append(Violation(line: index + 1, module: module))
    }
    return found
}

/// Parses `import X`, `@preconcurrency import X`, `import struct X.Y` and returns the top-level module.
func importedModule(_ line: String) -> String? {
    var tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
    while let first = tokens.first,
        first.hasPrefix("@") || first == "public" || first == "internal"
            || first == "private" || first == "fileprivate" || first == "package"
    {
        tokens.removeFirst()
    }
    guard tokens.first == "import", tokens.count >= 2 else { return nil }
    let kinds: Set<String> = ["struct", "class", "enum", "protocol", "typealias", "func", "var", "let"]
    let path = kinds.contains(tokens[1]) && tokens.count >= 3 ? tokens[2] : tokens[1]
    return path.split(separator: ".").first.map(String.init)
}
