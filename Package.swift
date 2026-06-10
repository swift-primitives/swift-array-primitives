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

        // MARK: - Bounded variant: DELETED (Q3-B ruling 2026-06-10 — dead surface; the
        // compile-time-dimensioned story lives at Index<E>.Bounded<N> + the inline column)

        // MARK: - Fixed variant: EXTRACTED to swift-fixed-primitives (W5-1, G2 ruling —
        // the truth-rename: Fixed<S> is a top-level family peer, not an Array variant;
        // modules `Fixed Primitive(+s)`). __ArrayProtocol stays HERE; Fixed's conformance
        // to it was withdrawn at extraction.

        // MARK: - Static variant

        // MARK: - Small variant

        // MARK: - Umbrella
        .library(name: "Array Primitives", targets: ["Array Primitives"]),

        // MARK: - Test Support
        .library(name: "Array Primitives Test Support", targets: ["Array Primitives Test Support"]),
    ],
    dependencies: [
        // swift-memory-small-primitives DROPPED at the W4 reshape: still spells the pre-W3
        // tower (un-migrated straggler); it was only listed preemptively for the never-built
        // Array.Small. Re-add when that variant lands on the new tower.
        .package(url: "https://github.com/swift-primitives/swift-span-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-standard-library-extensions.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-collection-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        // W2 mesh: buffer packages on their  worktrees so every path to memory
        // unifies on identity swift-memory-primitives (collision resolved).
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
        // W3 ⑤-(N): consumer spelling is now Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear,
        // so the substrate type Storage<Element>.Contiguous<Memory.Heap<Element>> is referenced directly.
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-cardinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-ordinal-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        // W4: the ADT tier is generic over the storage COLUMN (Store.Protocol & Buffer.Protocol seam);
        // the CoW column is the Shared combinator.
        .package(url: "https://github.com/swift-primitives/swift-store-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-shared-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-allocation-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Namespace + base type (struct Array; the heap/dynamic array)
        .target(
            name: "Array Primitive",
            dependencies: [
                .product(name: "Buffer Primitive", package: "swift-buffer-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Store Protocol Primitives", package: "swift-store-primitives"),
                .product(name: "Shared Primitive", package: "swift-shared-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
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
                .product(name: "Store Protocol Primitives", package: "swift-store-primitives"),
                .product(name: "Shared Primitive", package: "swift-shared-primitives"),
                .product(name: "Memory Allocator Primitive", package: "swift-memory-allocation-primitives"),
                .product(name: "Buffer Protocol Primitives", package: "swift-buffer-primitives"),
                .product(name: "Span Protocol Primitives", package: "swift-span-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
                .product(name: "Memory Iterator Primitives", package: "swift-memory-iterator-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
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
