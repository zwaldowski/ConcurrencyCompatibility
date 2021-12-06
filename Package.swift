// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ConcurrencyCompatibility",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .macCatalyst(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "ConcurrencyCompatibility",
            targets: ["ConcurrencyCompatibility"]),
    ],
    targets: [
        .target(
            name: "ConcurrencyCompatibility"),
        .testTarget(
            name: "ConcurrencyCompatibilityTests",
            dependencies: ["ConcurrencyCompatibility"]),
    ]
)
