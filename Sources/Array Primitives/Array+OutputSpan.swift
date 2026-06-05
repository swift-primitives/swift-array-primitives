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
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Storage_Contiguous_Primitives
public import Index_Primitives

// MARK: - Array + OutputSpan-based init / append / edit

extension Array where Element: ~Copyable {

    /// Creates a growable array with the given initial capacity, initialized via
    /// an `OutputSpan<Element>` closure.
    ///
    /// Matches the shape of `Swift.Array.init(capacity:initializingWith:)` and
    /// SE-0527's construction idiom. Delegates to
    /// `Buffer.Linear.init(capacity:initializingWith:)`.
    ///
    /// Unlike `Array.Fixed`, no full-population precondition is enforced — the
    /// resulting array's `count` reflects however many elements the closure
    /// appended. The allocated capacity may exceed `capacity`.
    ///
    /// ## Throwing behavior
    ///
    /// On throw, partially-initialized elements are deinitialized by the
    /// `OutputSpan`'s deinit; the array is not constructed; the error
    /// propagates.
    @inlinable
    public init<E: Swift.Error>(
        capacity: Array.Index.Count,
        initializingWith initializer: (inout Swift.OutputSpan<Element>) throws(E) -> Void
    ) throws(E) {
        self.init(_buffer: try Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear(
            capacity: capacity,
            initializingWith: initializer
        ))
    }

    /// Appends `addingCapacity` elements to the array via an `OutputSpan`
    /// closure, growing storage if needed.
    ///
    /// Matches the shape of `Swift.Array.append(addingCapacity:initializingWith:)`.
    ///
    /// When `Element: Copyable`, `Buffer.Linear`'s CoW-aware shadow is dispatched
    /// automatically: a copy is made before mutation if storage is shared.
    ///
    /// ## Throwing behavior
    ///
    /// Elements appended before a throw **remain committed** to the array
    /// (append-style semantics, distinct from init-style destroy-on-throw).
    @inlinable
    public mutating func append<E: Swift.Error>(
        addingCapacity: Array.Index.Count,
        initializingWith initializer: (inout Swift.OutputSpan<Element>) throws(E) -> Void
    ) throws(E) {
        try _buffer.append(
            addingCapacity: addingCapacity,
            initializingWith: initializer
        )
    }

    /// Edits the array's contents through an `OutputSpan<Element>` covering the
    /// entire allocated region `[0 ..< capacity)`, with `initializedCount` set
    /// to the current `count`.
    ///
    /// Matches SE-0527's `edit { }` general-purpose mutation escape hatch. The
    /// closure may append, remove, swap, or otherwise edit elements.
    ///
    /// ## Throwing behavior
    ///
    /// If the closure throws, the OutputSpan's current state is still committed
    /// (append-style semantics).
    @inlinable
    public mutating func edit<E: Swift.Error, R: ~Copyable>(
        _ body: (inout Swift.OutputSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        try _buffer.edit(body)
    }
}
