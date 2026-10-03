// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaCleanup",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaCleanup", targets: ["LumaCleanup"])
    ],
    dependencies: [
        .package(path: "../LumaCore"),
        .package(path: "../LumaSupport")
    ],
    targets: [
        .target(name: "LumaCleanup", dependencies: ["LumaCore", "LumaSupport"]),
        .testTarget(name: "LumaCleanupTests", dependencies: ["LumaCleanup"])
    ]
)
