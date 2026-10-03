// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaSystem",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaSystem", targets: ["LumaSystem"])
    ],
    dependencies: [
        .package(path: "../LumaCore"),
        .package(path: "../LumaSupport")
    ],
    targets: [
        .target(name: "LumaSystem", dependencies: ["LumaCore", "LumaSupport"]),
        .testTarget(name: "LumaSystemTests", dependencies: ["LumaSystem"])
    ]
)
