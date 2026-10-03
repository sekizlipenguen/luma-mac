// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaStartup",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaStartup", targets: ["LumaStartup"])
    ],
    dependencies: [
        .package(path: "../LumaCore"),
        .package(path: "../LumaSupport")
    ],
    targets: [
        .target(name: "LumaStartup", dependencies: ["LumaCore", "LumaSupport"]),
        .testTarget(name: "LumaStartupTests", dependencies: ["LumaStartup"])
    ]
)
