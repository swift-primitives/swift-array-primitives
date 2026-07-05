# ``Array_Primitives``

@Metadata {
    @DisplayName("Array Primitives")
    @TitleHeading("Swift Primitives")
}

A growable array ADT that is generic over its storage COLUMN — the carrier `__Array<S>`
composes any `Store.Protocol & Buffer.Protocol` column, and copyability flows from the
column, not from per-ADT machinery. Consumers spell the front doors: `Array<E>` (canonical)
and its variant aliases.

## Overview

The two ratified columns:

```swift
// Zero-cost MOVE-ONLY (the default ownership column):
__Array<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<FD>>.Linear>
// — the canonical front door: Array<FD>

// Explicit copy-on-write VALUE SEMANTICS (the Ownership.Shared column):
__Array<Ownership.Shared<Int, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Linear>>
// — the ownership-variant front door: Array<Int>.Shared
```

`__Array: Copyable where S: Copyable` — the `Ownership.Shared` column is `Copyable` exactly
when its element is, so value semantics are an explicit, visible choice at the type.

The element-generic surface (subscript, `count`, `withElement`, `pop`, `remove(at:)`,
`swap`, `drain`, `clone`) is written ONCE against the seam: mutating paths run the column's
semantic mutation gate (`unshare()`) before their first write, which restores
uniqueness on the `Ownership.Shared` column and is free on move-only columns. Only growth and
construction pin per column. `__Array: Equatable/Hashable where S: Equatable/Hashable` chains
element-keyed semantics through the `Ownership.Shared` carrier.

## Topics
