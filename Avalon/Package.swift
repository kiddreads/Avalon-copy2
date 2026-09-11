// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Avalon",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "AvalonCore", targets: ["AvalonCore"]),
    ],
    targets: [
        .target(name: "AvalonPixel"),
        .target(name: "AvalonJIT"),
        .target(name: "AvalonAudio"),
        .target(name: "AvalonChip8"),
        .target(
            name: "AvalonCore",
            dependencies: ["AvalonPixel", "AvalonJIT", "AvalonAudio", "AvalonChip8"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "avalon-verify", dependencies: ["AvalonCore"]),
        .executableTarget(name: "avalon-run", dependencies: ["AvalonCore", "AvalonAudio"]),
        .executableTarget(name: "avalon-notice", dependencies: ["AvalonCore"]),
        .executableTarget(name: "avalon-bench", dependencies: ["AvalonCore"]),
        .testTarget(name: "AvalonCoreTests", dependencies: ["AvalonCore"]),
    ]
)
