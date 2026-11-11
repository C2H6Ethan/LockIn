// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LockIn",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LockInCore", targets: ["LockInCore"]),
        .library(name: "LockInPlatform", targets: ["LockInPlatform"]),
    ],
    targets: [
        // Pure rules. Foundation only (ADR 0002).
        .target(name: "LockInCore"),
        // Thin adapters over Apple frameworks. No rules.
        .target(name: "LockInPlatform", dependencies: ["LockInCore"]),
        .testTarget(name: "LockInCoreTests", dependencies: ["LockInCore"]),
    ]
)
