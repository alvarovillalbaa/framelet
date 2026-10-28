// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Framelet",
    platforms: [.macOS("15.0")],
    products: [
        .executable(name: "Framelet", targets: ["Framelet"]),
        .library(name: "FrameletCore", targets: ["FrameletCore"]),
    ],
    targets: [
        .target(name: "FrameletCore"),
        .executableTarget(name: "Framelet", dependencies: ["FrameletCore"]),
        .testTarget(name: "FrameletCoreTests", dependencies: ["FrameletCore"]),
        .testTarget(name: "FrameletPlaybackTests", dependencies: ["Framelet", "FrameletCore"]),
    ]
)
