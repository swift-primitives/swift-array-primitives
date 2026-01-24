// swift-tools-version: 6.2

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
    ],
    dependencies: [
        .package(path: "../swift-standard-library-extensions"),
        .package(path: "../swift-bit-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-sequence-primitives"),
        .package(path: "../swift-range-primitives"),
    ],
    targets: [
        // Core types with ~Copyable support (Array, Fixed, Static, Small structs)
        .target(
            name: "Array Primitives Core",
            dependencies: [
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Bit Primitives", package: "swift-bit-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Per-variant modules: Swift.Sequence/Collection conformances (Element: Copyable)
        // Separate modules to avoid constraint poisoning on Core types
        .target(
            name: "Array Dynamic Primitives",  // Base Array (growable, heap)
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
            ]
        ),
        .target(
            name: "Array Fixed Primitives",  // Fixed-count heap array
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
            ]
        ),
        .target(
            name: "Array Static Primitives",  // Fixed-capacity inline (was Inline)
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
            ]
        ),
        .target(
            name: "Array Small Primitives",
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Range Primitives", package: "swift-range-primitives"),
            ]
        ),
        .target(
            name: "Array Bit Primitives",
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        // Public: Re-exports Core and all variant modules
        .target(
            name: "Array Primitives",
            dependencies: [
                "Array Primitives Core",
                "Array Dynamic Primitives",
                "Array Fixed Primitives",
                "Array Static Primitives",
                "Array Small Primitives",
                "Array Bit Primitives",
            ]
        ),
        .testTarget(
            name: "Array Primitives Tests",
            dependencies: ["Array Primitives"]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
