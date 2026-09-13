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
        // The libretro API header is MIT and scoped to itself; hosting cores through it takes on
        // no copyleft from RetroArch, which is GPL-3.0.
        .target(name: "AvalonLibretro"),
        // A libretro core that exists only to test the frontend against the real ABI.
        .target(name: "AvalonLibretroTestCore", dependencies: ["AvalonLibretro"]),
        .target(
            name: "AvalonCore",
            dependencies: ["AvalonPixel", "AvalonJIT", "AvalonAudio", "AvalonChip8", "AvalonLibretro"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "avalon-verify", dependencies: ["AvalonCore"]),
        .executableTarget(name: "avalon-run", dependencies: ["AvalonCore", "AvalonAudio"]),
        .executableTarget(name: "avalon-notice", dependencies: ["AvalonCore"]),
        .executableTarget(name: "avalon-bench", dependencies: ["AvalonCore"]),
        .executableTarget(name: "avalon-controls", dependencies: ["AvalonCore"]),
        .testTarget(name: "AvalonCoreTests",
                    dependencies: ["AvalonCore", "AvalonLibretroTestCore"]),
    ]
)
