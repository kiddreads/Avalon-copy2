// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Avalon",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "AvalonCore", targets: ["AvalonCore"]),
    ],
    targets: [
        .target(
            name: "AvalonCore",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "AvalonCoreTests", dependencies: ["AvalonCore"]),
    ]
)
