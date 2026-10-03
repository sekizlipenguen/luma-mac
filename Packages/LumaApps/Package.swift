// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaApps",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaApps", targets: ["LumaApps"])
    ],
    dependencies: [
        .package(path: "../LumaCore"),
        .package(path: "../LumaSupport")
    ],
    targets: [
        .target(name: "LumaApps", dependencies: ["LumaCore", "LumaSupport"]),
        .testTarget(name: "LumaAppsTests", dependencies: ["LumaApps"])
    ]
)
