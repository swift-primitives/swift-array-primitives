// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "separate-module-conformance",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ArrayCore", targets: ["ArrayCore"]),
        .library(name: "ArraySequence", targets: ["ArraySequence"]),
        .executable(name: "test-runner", targets: ["TestRunner"]),
    ],
    dependencies: [
        .package(path: "../../../swift-sequence-primitives"),
    ],
    targets: [
        // Core module: ~Copyable array WITHOUT any Sequence/Collection conformances
        .target(
            name: "ArrayCore",
            path: "Sources/array-core"
        ),
        // Sequence module: Retroactive conformances for Copyable elements
        .target(
            name: "ArraySequence",
            dependencies: [
                "ArrayCore",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ],
            path: "Sources/array-sequence"
        ),
        // Test runner
        .executableTarget(
            name: "TestRunner",
            dependencies: ["ArrayCore", "ArraySequence"],
            path: "Sources/test-runner"
        ),
    ],
    swiftLanguageModes: [.v6]
)
