// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaUI",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaUI", targets: ["LumaUI"])
    ],
    dependencies: [
        .package(path: "../LumaCore")
    ],
    targets: [
        .target(name: "LumaUI", dependencies: ["LumaCore"]),
        .testTarget(name: "LumaUITests", dependencies: ["LumaUI"])
    ]
)
