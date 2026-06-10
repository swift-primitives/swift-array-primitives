// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Array_Primitive
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Index_Primitives

// MARK: - Array + OutputSpan-based init / append / edit (direct column)
//
// The SE-0527 construction/append/edit idioms, pinned to the direct move-only column
// (the windows forward the buffer's own OutputSpan surfaces). The `Shared` column's
// OutputSpan surface arrives with `Shared`-side `edit`/windowed-append forwards,
// recorded as future work — its construction path is covered by the pinned
// `Array(initialCapacity:)` + `append` ops.

extension Array where S: ~Copyable {

    /// Creates a growable array with the given initial capacity, initialized via an
    /// `OutputSpan<E>` closure (direct column).
    ///
    /// ## Throwing behavior
    ///
    /// On throw, partially-initialized elements are deinitialized by the `OutputSpan`'s
    /// deinit; the array is not constructed; the error propagates.
    @inlinable
    public init<E: ~Copyable, Failure: Swift.Error>(
        capacity: Index_Primitives.Index<E>.Count,
        initializingWith initializer: (inout Swift.OutputSpan<E>) throws(Failure) -> Void
    ) throws(Failure)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        self.init(store: try Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear(
            capacity: capacity,
            initializingWith: initializer
        ))
    }

    /// Appends `addingCapacity` elements via an `OutputSpan` closure, growing storage if
    /// needed (direct column).
    ///
    /// ## Throwing behavior
    ///
    /// Elements appended before a throw **remain committed** to the array (append-style
    /// semantics, distinct from init-style destroy-on-throw).
    @inlinable
    public mutating func append<E: ~Copyable, Failure: Swift.Error>(
        addingCapacity: Index_Primitives.Index<E>.Count,
        initializingWith initializer: (inout Swift.OutputSpan<E>) throws(Failure) -> Void
    ) throws(Failure)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        try store.append(
            addingCapacity: addingCapacity,
            initializingWith: initializer
        )
    }

    /// Edits the array's contents through an `OutputSpan<E>` covering the entire allocated
    /// region `[0 ..< capacity)`, with `initializedCount` set to the current `count`
    /// (direct column).
    ///
    /// ## Throwing behavior
    ///
    /// If the closure throws, the OutputSpan's current state is still committed
    /// (append-style semantics).
    @inlinable
    public mutating func edit<E: ~Copyable, Failure: Swift.Error, R: ~Copyable>(
        _ body: (inout Swift.OutputSpan<E>) throws(Failure) -> R
    ) throws(Failure) -> R
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        try store.edit(body)
    }
}
