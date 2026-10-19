// swift-tools-version: 6.2
import PackageDescription

let strict: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "Handy",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HandyCore", targets: ["HandyCore"]),
        .library(name: "HandyPerception", targets: ["HandyPerception"]),
        .library(name: "HandyOutput", targets: ["HandyOutput"]),
        .library(name: "HandyReplay", targets: ["HandyReplay"]),
        .library(name: "HandyControl", targets: ["HandyControl"]),
        .library(name: "HandyApp", targets: ["HandyApp"]),
        .executable(name: "Handy", targets: ["Handy"]),
        .executable(name: "handyctl", targets: ["handyctl"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "HandyCore",
            swiftSettings: strict,
            plugins: ["FencePlugin"]
        ),
        .target(name: "HandyPerception", dependencies: ["HandyCore"], swiftSettings: strict),
        .target(name: "HandyOutput", dependencies: ["HandyCore"], swiftSettings: strict),
        .target(name: "HandyReplay", dependencies: ["HandyCore"], swiftSettings: strict),
        .target(name: "HandyControl", dependencies: ["HandyCore"], swiftSettings: strict),
        .target(
            name: "HandyApp",
            dependencies: [
                "HandyCore", "HandyPerception", "HandyOutput", "HandyReplay", "HandyControl",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: strict
        ),
        .executableTarget(name: "Handy", dependencies: ["HandyApp"], swiftSettings: strict),
        .executableTarget(
            name: "handyctl",
            dependencies: [
                "HandyCore", "HandyReplay", "HandyOutput", "HandyPerception", "HandyControl",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: strict
        ),
        .executableTarget(name: "FenceCheck", swiftSettings: strict),
        .plugin(name: "FencePlugin", capability: .buildTool(), dependencies: ["FenceCheck"]),
        .testTarget(
            name: "HandyCoreTests", dependencies: ["HandyCore"], resources: [.copy("Fixtures")], swiftSettings: strict),
        .testTarget(
            name: "HandyReplayTests",
            dependencies: ["HandyCore", "HandyReplay"],
            resources: [.copy("Fixtures")],
            swiftSettings: strict
        ),
        .testTarget(
            name: "HandyPerceptionTests", dependencies: ["HandyPerception", "HandyCore", "HandyReplay"],
            swiftSettings: strict),
        .testTarget(name: "HandyOutputTests", dependencies: ["HandyOutput", "HandyCore"], swiftSettings: strict),
        .testTarget(name: "HandyAppTests", dependencies: ["HandyApp", "HandyCore"], swiftSettings: strict),
        .testTarget(name: "HandyControlTests", dependencies: ["HandyControl", "HandyCore"], swiftSettings: strict),
        .testTarget(name: "FenceCheckTests", dependencies: ["FenceCheck"], swiftSettings: strict),
    ]
)
