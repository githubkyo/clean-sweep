// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CleanSweep",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CleanSweep",
            path: "Sources"
        ),
    ]
)
