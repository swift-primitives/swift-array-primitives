// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "array-totality-patterns",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-index-primitives")
    ],
    targets: [
        .executableTarget(
            name: "array-totality-patterns",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives")
            ]
        )
    ]
)
