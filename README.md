# Array Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-primitives/swift-array-primitives/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-primitives/swift-array-primitives/actions/workflows/ci.yml)

A growable array generic over its storage **column** — `Array<S>` composes any contiguous buffer column, and copyability flows from the column rather than from per-array machinery. The element-generic surface (subscript, `count`, `append`, `remove`, `swap`, span access) is written once against the column seam; only growth and construction specialize per column.

The two ratified columns answer the ownership question at the type level. `Column.Heap<E>` is the move-only default — the array owns its heap storage outright and is consumed or borrowed, never silently copied. `Column.Shared<E>` is the explicit copy-on-write column — the array becomes `Copyable` exactly when its element is, so value semantics are a visible choice rather than an implicit cost.

---

## Key Features

- **Column-generic storage** — one `Array<S>` type composes any storage column; the backing is a type parameter, not a separate type per policy.
- **Copyability from the column** — move-only by default (`Column.Heap`), opt-in copy-on-write (`Column.Shared`); no hidden retain traffic on the move-only path.
- **Noncopyable elements** — full `~Copyable` element support on the move-only column.
- **Contiguous and span-friendly** — amortized O(1) `append`, direct `MutableSpan` access, and a C-interop buffer escape hatch.

---

## Quick Start

```swift
import Array_Primitives

// Move-only by default: the array owns its heap storage outright — no implicit copies.
var log = Array<Int>()
log.append(200)
log.append(404)
let entries = log.count                 // 2

// Opt in to copy-on-write value semantics with the Shared front door:
var snapshot = Array<Int>.Shared()
snapshot.append(200)
let archived = snapshot                 // shares storage (O(1)) — no copy yet
snapshot.append(404)                    // forks here; `archived` still holds [200]
```

`Array<E>` is the canonical front door: a growable, move-only array pinned to the heap-allocated, contiguous linear column. `Array<E>.Shared` is the ownership-axis variant — the same column boxed behind `Ownership.Shared`, `Copyable` exactly when `E` is. `Array<E>.Small<n>` (in the separate `Array Small Primitive` product) re-points the allocation axis to an inline-until-it-spills buffer, where `n` is a byte budget rather than an element count.

---

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-array-primitives.git", branch: "main")
]
```

Add a product to your target:

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Array Primitives", package: "swift-array-primitives")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Array Primitives` | Umbrella — `Array<E>`, `Array<E>.Shared`, and the `Collection` / `Sequence` conformances | Most consumers |
| `Array Primitive` | The `__Array<S>` carrier and its front-door aliases (`Array<E>`, `Array<E>.Shared`), without the conformances | Move-only use that must not pull in conformance machinery |
| `Array Protocol Primitives` | The array seam protocol that `__Array<S>` conforms to | Writing code generic over array-like storage |
| `Array Small Primitive` | `Array<E>.Small<n>`, the inline-until-it-spills allocation variant ([DS-027].1) | Consumers who need a byte-budgeted inline buffer, e.g. `json` |
| `Array Primitives Test Support` | Re-exported test-support helpers for consumers testing against `Array Primitives` | Test targets only |

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-buffer-primitives`](https://github.com/swift-primitives/swift-buffer-primitives) / [`swift-buffer-linear-primitives`](https://github.com/swift-primitives/swift-buffer-linear-primitives) — the contiguous linear buffer the front doors pin to.
- [`swift-storage-primitives`](https://github.com/swift-primitives/swift-storage-primitives) — the `Store.Protocol` / `Storage.Contiguous` seam the buffer is generic over.
- [`swift-memory-heap-primitives`](https://github.com/swift-primitives/swift-memory-heap-primitives) / [`swift-memory-allocation-primitives`](https://github.com/swift-primitives/swift-memory-allocation-primitives) / [`swift-memory-small-primitives`](https://github.com/swift-primitives/swift-memory-small-primitives) — the allocation leaves (`Memory.Heap`, `Memory.Allocator`, `Memory.Small<n>`) that back `Array<E>` and `Array<E>.Small<n>`.
- [`swift-ownership-shared-primitives`](https://github.com/swift-primitives/swift-ownership-shared-primitives) — the copy-on-write box behind `Array<E>.Shared`.
- [`swift-index-primitives`](https://github.com/swift-primitives/swift-index-primitives) / [`swift-collection-primitives`](https://github.com/swift-primitives/swift-collection-primitives) / [`swift-sequence-primitives`](https://github.com/swift-primitives/swift-sequence-primitives) — the indexing and iteration seams `Array<E>` conforms to.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
