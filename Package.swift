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
        // MARK: - Namespace + base type
        .library(name: "Array Primitive", targets: ["Array Primitive"]),

        // MARK: - Inline

        // MARK: - Protocol
        .library(name: "Array Protocol Primitives", targets: ["Array Protocol Primitives"]),

        // MARK: - Bounded variant
        .library(name: "Array Bounded Primitive", targets: ["Array Bounded Primitive"]),
        .library(name: "Array Bounded Primitives", targets: ["Array Bounded Primitives"]),

        // MARK: - Fixed variant
        .library(name: "Array Fixed Primitive", targets: ["Array Fixed Primitive"]),
        .library(name: "Array Fixed Primitives", targets: ["Array Fixed Primitives"]),

        // MARK: - Static variant

        // MARK: - Small variant

        // MARK: - Umbrella
        .library(name: "Array Primitives", targets: ["Array Primitives"]),

        // MARK: - Test Support
        .library(name: "Array Primitives Test Support", targets: ["Array Primitives Test Support"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-memory-small-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-standard-library-extensions.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-collection-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        // W2 mesh: buffer packages on their  worktrees so every path to memory
        // unifies on identity swift-memory-primitives (collision resolved).
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
        // W3 ⑤-(N): consumer spelling is now Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear,
        // so the substrate type Storage<Element>.Contiguous<Memory.Heap<Element>> is referenced directly.
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-finite-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cardinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-equation-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Namespace + base type (struct Array; the heap/dynamic array)
        .target(
            name: "Array Primitive",
            dependencies: [
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Inline (typealias to Swift.InlineArray)

        // MARK: - Protocol (Array.Protocol membership contract + defaults)
        .target(
            name: "Array Protocol Primitives",
            dependencies: [
                "Array Primitive",
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Bounded type
        .target(
            name: "Array Bounded Primitive",
            dependencies: [
                "Array Primitive",
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
            ]
        ),

        // MARK: - Bounded ops
        .target(
            name: "Array Bounded Primitives",
            dependencies: [
                "Array Bounded Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Finite Primitives", package: "swift-finite-primitives"),
            ]
        ),

        // MARK: - Fixed type
        .target(
            name: "Array Fixed Primitive",
            dependencies: [
                "Array Primitive",
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
            ]
        ),

        // MARK: - Fixed ops
        .target(
            name: "Array Fixed Primitives",
            dependencies: [
                "Array Fixed Primitive",
                "Array Protocol Primitives",
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Iterator Primitives", package: "swift-memory-iterator-primitives"),
                .product(name: "Buffer Linear Bounded Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Equation Primitives Standard Library Integration", package: "swift-equation-primitives"),
                .product(name: "Hash Primitives Standard Library Integration", package: "swift-hash-primitives"),
            ]
        ),

        // MARK: - Static type

        // MARK: - Static ops

        // MARK: - Small type

        // MARK: - Small ops

        // MARK: - Base ops + Umbrella ([MOD-005] dual-role: base Array conformances + re-export of all variants)
        .target(
            name: "Array Primitives",
            dependencies: [
                "Array Primitive",
                "Array Protocol Primitives",
                "Array Bounded Primitives",
                "Array Fixed Primitives",
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Iterator Primitives", package: "swift-memory-iterator-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                // Cleave-3 #12a/#5a: Array.Small composes Buffer<Storage<E>.Small<n>>.Linear (absorbed substrate).
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
                .product(name: "Equation Primitives Standard Library Integration", package: "swift-equation-primitives"),
                .product(name: "Hash Primitives Standard Library Integration", package: "swift-hash-primitives"),
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
