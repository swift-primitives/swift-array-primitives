// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-array-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Array Primitives",
            targets: ["Array Primitives"]
        ),
        .library(
            name: "Array Primitives Core",
            targets: ["Array Primitives Core"]
        ),
        .library(
            name: "Array Small Primitives",
            targets: ["Array Small Primitives"]
        ),
        .library(
            name: "Array Static Primitives",
            targets: ["Array Static Primitives"]
        ),
        .library(
            name: "Array Fixed Primitives",
            targets: ["Array Fixed Primitives"]
        ),
        .library(
            name: "Array Dynamic Primitives",
            targets: ["Array Dynamic Primitives"]
        ),
        .library(
            name: "Array Bounded Primitives",
            targets: ["Array Bounded Primitives"]
        ),
        .library(
            name: "Array Primitives Test Support",
            targets: ["Array Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-standard-library-extensions"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-sequence-primitives"),
        .package(path: "../swift-buffer-primitives"),
        .package(path: "../swift-algebra-modular-primitives"),
        .package(path: "../swift-equation-primitives"),
        .package(path: "../swift-hash-primitives"),
        .package(path: "../swift-tagged-primitives"),
        .package(path: "../swift-ordinal-primitives"),
    ],
    targets: [

        // MARK: - Core
        .target(
            name: "Array Primitives Core",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Small Primitives", package: "swift-buffer-primitives"),
            ]
        ),

        // MARK: - Dynamic
        .target(
            name: "Array Dynamic Primitives",
            dependencies: [
                "Array Primitives Core",
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),

        // MARK: - Fixed
        .target(
            name: "Array Fixed Primitives",
            dependencies: [
                "Array Primitives Core",
            ]
        ),

        // MARK: - Static
        .target(
            name: "Array Static Primitives",
            dependencies: [
                "Array Primitives Core",
            ]
        ),

        // MARK: - Small
        .target(
            name: "Array Small Primitives",
            dependencies: [
                "Array Primitives Core",
                .product(name: "Buffer Linear Small Primitives", package: "swift-buffer-primitives"),
            ]
        ),

        // MARK: - Bounded
        .target(
            name: "Array Bounded Primitives",
            dependencies: [
                "Array Primitives Core",
                .product(name: "Algebra Modular Primitives", package: "swift-algebra-modular-primitives"),
                .product(name: "Equation Primitives", package: "swift-equation-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
            ]
        ),

        // MARK: - Umbrella
        .target(
            name: "Array Primitives",
            dependencies: [
                "Array Primitives Core",
                "Array Dynamic Primitives",
                "Array Fixed Primitives",
                "Array Static Primitives",
                "Array Small Primitives",
                "Array Bounded Primitives",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Array Primitives Test Support",
            dependencies: [
                "Array Primitives",
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Array Primitives Tests",
            dependencies: [
                "Array Primitives",
                "Array Primitives Test Support",
                .product(name: "Tagged Primitives Standard Library Integration", package: "swift-tagged-primitives"),
                .product(name: "Ordinal Primitives Standard Library Integration", package: "swift-ordinal-primitives"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
