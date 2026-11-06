// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NostargiaKit",
    defaultLocalization: "ja",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NostargiaKit", targets: ["NostargiaKit"]),
    ],
    targets: [
        .target(
            name: "NostargiaKit",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "NostargiaKitTests",
            dependencies: ["NostargiaKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
