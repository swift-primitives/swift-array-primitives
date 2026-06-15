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
import Column_Primitives

// Move-only by default: the array owns its heap storage outright — no implicit copies.
var log = Array<Column.Heap<Int>>()
log.append(200)
log.append(404)
let entries = log.count                 // 2

// Opt in to copy-on-write value semantics with the Shared column:
var snapshot = Array<Column.Shared<Int>>()
snapshot.append(200)
let archived = snapshot                 // shares storage (O(1)) — no copy yet
snapshot.append(404)                    // forks here; `archived` still holds [200]
```

Storage is chosen by the column type parameter, so the same `Array<S>` covers more than these two — `Column.Inline<E, n>`, for example, keeps elements in the value itself with no heap allocation. Small-buffer storage (inline until it spills) awaits a future `Column.Small`.

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
| `Array Primitives` | Umbrella — `Array<S>`, the column constructors, and the `Collection` / `Sequence` conformances | Most consumers |
| `Array Primitive` | The `Array<S>` value type and its column-pinned surface, without the conformances | Move-only use that must not pull in conformance machinery |
| `Array Protocol Primitives` | The array seam protocol that `Array<S>` conforms to | Writing code generic over array-like storage |

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

- [`swift-column-primitives`](https://github.com/swift-primitives/swift-column-primitives) — the column vocabulary (`Column.Heap`, `Column.Shared`, …) the array composes.
- [`swift-shared-primitives`](https://github.com/swift-primitives/swift-shared-primitives) — the copy-on-write box behind the `Shared` column.
- [`swift-fixed-primitives`](https://github.com/swift-primitives/swift-fixed-primitives) — the fixed-count discipline over a capacity-capped column.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
