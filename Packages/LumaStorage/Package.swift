// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumaStorage",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LumaStorage", targets: ["LumaStorage"])
    ],
    dependencies: [
        .package(path: "../LumaCore"),
        .package(path: "../LumaSupport")
    ],
    targets: [
        .target(name: "LumaStorage", dependencies: ["LumaCore", "LumaSupport"]),
        .testTarget(name: "LumaStorageTests", dependencies: ["LumaStorage"])
    ]
)
