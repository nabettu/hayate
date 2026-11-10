// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WatchHookCore",
    defaultLocalization: "ja",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [
        .library(name: "WatchHookCore", targets: ["WatchHookCore"]),
    ],
    targets: [
        .target(name: "WatchHookCore", resources: [.process("Localizable.xcstrings")]),
        .testTarget(name: "WatchHookCoreTests", dependencies: ["WatchHookCore"]),
    ]
)
