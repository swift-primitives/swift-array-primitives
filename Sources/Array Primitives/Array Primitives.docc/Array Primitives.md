# ``Array_Primitives``

@Metadata {
    @DisplayName("Array Primitives")
    @TitleHeading("Swift Primitives")
}

A growable array ADT that is generic over its storage COLUMN — `Array<S>` composes any
`Store.Protocol & Buffer.Protocol` column, and copyability flows from the column, not from
per-ADT machinery.

## Overview

The two ratified columns:

```swift
// Zero-cost MOVE-ONLY (the default ownership column):
Array<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<FD>>.Linear>

// Explicit copy-on-write VALUE SEMANTICS (the Shared column):
Array<Shared<Int, Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Int>>.Linear>>
```

`Array: Copyable where S: Copyable` — the `Shared` column is `Copyable` exactly when its
element is, so value semantics are an explicit, visible choice at the type.

The element-generic surface (subscript, `count`, `withElement`, `removeLast`, `remove(at:)`,
`swap`, `drain`, `clone`) is written ONCE against the seam: mutating paths run the column's
semantic mutation gate (`prepareForMutation()`) before their first write, which restores
uniqueness on the `Shared` column and is free on move-only columns. Only growth and
construction pin per column. `Array: Equatable/Hashable where S: Equatable/Hashable` chains
element-keyed semantics through the `Shared` carrier.

## Topics
