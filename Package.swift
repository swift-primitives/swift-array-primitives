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
    ],
    targets: [
        // Core types with ~Copyable support (Array, Fixed, Static, Small, Bounded structs)
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
        // Per-variant modules: Swift.Sequence/Collection conformances (Element: Copyable)
        // Separate modules to avoid constraint poisoning on Core types
        .target(
            name: "Array Dynamic Primitives",  // Base Array (growable, heap)
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
            ]
        ),
        .target(
            name: "Array Fixed Primitives",  // Fixed-count heap array
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        .target(
            name: "Array Static Primitives",  // Fixed-capacity inline (was Inline)
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
            ]
        ),
        .target(
            name: "Array Small Primitives",
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Buffer Linear Small Primitives", package: "swift-buffer-primitives"),
            ]
        ),
        .target(
            name: "Array Bounded Primitives",  // Compile-time dimensioned (Algebra.Z<N> indexing)
            dependencies: [
                "Array Primitives Core",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Algebra Modular Primitives", package: "swift-algebra-modular-primitives"),
                .product(name: "Equation Primitives", package: "swift-equation-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
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
                "Array Bounded Primitives",
            ]
        ),
        .target(
            name: "Array Primitives Test Support",
            dependencies: [
                "Array Primitives",
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Array Primitives Tests",
            dependencies: [
                "Array Primitives",
                "Array Primitives Test Support",
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableExperimentalFeature("BuiltinModule"),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InferSendableFromCaptures"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
        .enableExperimentalFeature("ValueGenerics"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
