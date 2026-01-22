// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "conditional-copyable-experiment",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ConditionalCopyableExperiment", targets: ["ConditionalCopyableExperiment"]),
    ],
    targets: [
        .target(
            name: "ConditionalCopyableExperiment",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("AllowUnsafeAttribute"),
                .enableExperimentalFeature("AddressableTypes"),
                .enableExperimentalFeature("InoutLifetimeDependence"),
            ]
        ),
        .testTarget(
            name: "ConditionalCopyableExperimentTests",
            dependencies: ["ConditionalCopyableExperiment"],
            path: "Tests"
        ),
    ]
)
