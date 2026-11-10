// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RippleCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: ["RippleEngine", "LearningModel", "ContentKit", "SyncKit"].map {
        .library(name: $0, targets: [$0])
    },
    targets: [
        .target(name: "RippleEngine"),
        .target(name: "LearningModel", dependencies: ["RippleEngine"]),
        .target(name: "ContentKit", dependencies: ["RippleEngine"]),
        .target(name: "SyncKit", dependencies: ["LearningModel"]),
        .testTarget(name: "RippleCoreTests", dependencies: ["RippleEngine", "LearningModel", "ContentKit", "SyncKit"])
    ]
)
