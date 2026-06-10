// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KOTCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "KOTCore", targets: ["KOTCore"]),
        .library(name: "KOTNotifications", targets: ["KOTNotifications"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "KOTCore",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "KOTNotifications",
            dependencies: ["KOTCore"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "KOTCoreTests",
            dependencies: ["KOTCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "KOTNotificationsTests",
            dependencies: ["KOTNotifications"]
        ),
    ]
)
