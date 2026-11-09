// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WatchHookCore",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [
        .library(name: "WatchHookCore", targets: ["WatchHookCore"]),
    ],
    targets: [
        .target(name: "WatchHookCore"),
        .testTarget(name: "WatchHookCoreTests", dependencies: ["WatchHookCore"]),
    ]
)
