// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "noncopyable-sequence-protocol-test",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-sequence-primitives"),
        .package(path: "../../../swift-collection-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "noncopyable-sequence-protocol-test",
            dependencies: [
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        )
    ]
)
