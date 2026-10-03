// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaSupport",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaSupport", targets: ["LumaSupport"])
    ],
    dependencies: [
        .package(path: "../LumaCore")
    ],
    targets: [
        .target(name: "LumaSupport", dependencies: ["LumaCore"]),
        .testTarget(name: "LumaSupportTests", dependencies: ["LumaSupport"])
    ]
)
