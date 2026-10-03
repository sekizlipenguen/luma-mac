// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaCore", targets: ["LumaCore"])
    ],
    targets: [
        .target(name: "LumaCore"),
        .testTarget(name: "LumaCoreTests", dependencies: ["LumaCore"])
    ]
)
