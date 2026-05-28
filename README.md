# Array Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

The **array discipline** over the `Array` namespace: growable, fixed, static, small-buffer-optimized, bounded, and inline variants, all supporting noncopyable (`~Copyable`) elements.

---

## Quick Start

```swift
import Array_Primitives

// Growable, heap-backed — copy-on-write when Element is Copyable.
var events = Array<String>()
events.append("login")
events.append("purchase")
let count = events.count                         // 2
_ = events.remove.last()                         // "purchase"

// Small-buffer optimization — inline until it overflows, then spills to the heap.
var recentIDs = Array<Int>.Small<8>()
for id in 1001...1010 { recentIDs.append(id) }  // 10th append spills to heap
let first = recentIDs.span[0]                    // 1001

// Fixed — all elements initialized at construction; count never changes.
let slots = try Array<Int>.Fixed(count: 4) { $0.rawValue }
var values: [Int] = []
slots.forEach { values.append($0) }             // [0, 1, 2, 3]

// Static — inline storage, variable count, no heap allocation.
var buffer = Array<UInt8>.Static<16>()
try buffer.append(0xFF)
try buffer.append(0x0A)
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-array-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        // The umbrella — the whole package.
        .product(name: "Array Primitives", package: "swift-array-primitives"),
        // …or depend on just the variant you use, e.g.:
        // .product(name: "Array Small Primitives", package: "swift-array-primitives"),
        // .product(name: "Array Fixed Primitives", package: "swift-array-primitives"),
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3
and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux toolchain).

---

## Variants

| Type | Storage | Reach for it when |
|------|---------|-------------------|
| `Array<Element>` | heap, growable (CoW) | the size isn't known up front |
| `Array<Element>.Bounded<N>` | heap, compile-time dimension | you need type-safe index separation between arrays of different sizes |
| `Array<Element>.Fixed` | heap, fixed count | all elements are known at creation and the count must never change |
| `Array<Element>.Static<N>` | inline, fixed capacity | the maximum is small and known at compile time, and no heap allocation is acceptable |
| `Array<Element>.Small<N>` | inline → heap | usually short-lived or small, occasionally larger (SBO) |
| `Array<Element>.Inline<N>` | inline, always full | all N slots must be initialized; typealias to `Swift.InlineArray` |

`Array`, `Array.Bounded`, `Array.Fixed`, and `Array.Small` support noncopyable (`~Copyable`)
elements. `Array.Static` is unconditionally `~Copyable` due to inline storage deinit requirements.
`Array.Inline` inherits `Swift.InlineArray`'s element constraints.

---

## Architecture

Each variant ships as **two modules**: a lean type module (e.g., `Array Small Primitive`) that
declares the value type and its storage, and a conformances module (e.g., `Array Small Primitives`)
that adds `Collection`, `Sequence`, and property-view conformances — kept separate so they never
constrain noncopyable use-sites. Importing `Array Primitives` (the umbrella) brings the whole
package; importing a single variant's conformances module brings in just that variant.

---

## License

Apache License 2.0. See [LICENSE](LICENSE.md) for details.
