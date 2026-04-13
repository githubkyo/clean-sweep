// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CleanSweep",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CleanSweep",
            path: "Sources",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CleanSweepTests",
            dependencies: ["CleanSweep"],
            path: "Tests"
        ),
    ]
)
