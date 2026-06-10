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

// The COLUMN-PINNED surface: growth and storage-shape operations cannot ride the seam
// (no growth capability there by design), so each op appears once per ratified column —
// the direct move-only heap buffer, and the `Shared` CoW box over it (whose ops are
// CoW-checked inside `Shared`). The pins are `where ==` clauses on METHODS (mechanic #2:
// extensions cannot introduce free element parameters; methods can).
public import Array_Primitive
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Linear_Primitives
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Shared_Primitive
public import Index_Primitives

// ============================================================================
// MARK: - Append (growth)
// ============================================================================

extension Array where S: ~Copyable {
    /// Appends an element to the array (direct move-only column).
    ///
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func append<E: ~Copyable>(_ element: consuming E)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        store.append(element)
    }

    /// Appends an element to the array (`Shared` CoW column; uniqueness-checked).
    ///
    /// - Complexity: O(1) amortized (O(n) when a copy must be made first).
    @inlinable
    public mutating func append<E>(_ element: consuming E)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear> {
        store.append(element)
    }

    /// Appends an element on the statically-unique (~Copyable element) `Shared` column.
    @inlinable
    public mutating func append<E: ~Copyable>(_ element: consuming E)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear> {
        store.appendAssumingUnique(element)
    }
}

// ============================================================================
// MARK: - Remove All (storage rebinding)
// ============================================================================

extension Array where S: ~Copyable {
    /// Removes all elements (direct move-only column).
    @inlinable
    public mutating func removeAll<E: ~Copyable>(keepingCapacity: Bool = false)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        store.removeAll(keepingCapacity: keepingCapacity)
    }

    /// Removes all elements (`Shared` CoW column).
    ///
    /// Detaches to a fresh box rather than draining in place: sibling values sharing the
    /// old box keep their elements untouched, and no deep copy is ever needed.
    @inlinable
    public mutating func removeAll<E>(keepingCapacity: Bool = false)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear> {
        let capacity: Index_Primitives.Index<E>.Count = keepingCapacity ? store.capacity : .zero
        self.store = Shared(
            Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear(
                minimumCapacity: capacity
            )
        )
    }
}

// ============================================================================
// MARK: - Capacity (growth / reshape)
// ============================================================================

extension Array where S: ~Copyable {
    /// Ensures at least `minimumCapacity` slots are allocated (direct column).
    @inlinable
    public mutating func reserveCapacity<E: ~Copyable>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        store.reserveCapacity(minimumCapacity)
    }

    /// Ensures at least `minimumCapacity` slots are allocated (`Shared` column; uniquely).
    @inlinable
    public mutating func reserveCapacity<E>(_ minimumCapacity: Index_Primitives.Index<E>.Count)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear> {
        store.reserveCapacity(minimumCapacity)
    }

    /// Grows or shrinks storage to exactly `newCapacity`, preserving elements (direct column).
    ///
    /// - Precondition: `newCapacity >= count`
    @inlinable
    public mutating func reallocate<E: ~Copyable>(capacity newCapacity: Index_Primitives.Index<E>.Count)
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        store.reallocate(capacity: newCapacity)
    }

    /// Grows or shrinks storage to exactly `newCapacity` (`Shared` column; uniquely).
    ///
    /// - Precondition: `newCapacity >= count`
    @inlinable
    public mutating func reallocate<E>(capacity newCapacity: Index_Primitives.Index<E>.Count)
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear> {
        store.reallocate(capacity: newCapacity)
    }
}

// ============================================================================
// MARK: - Cloning (direct column; the generic `clone()` covers the CoW column)
// ============================================================================

extension Array where S: ~Copyable {
    /// Returns an independent copy of this array sized to exactly fit `count` (direct column).
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public func clone<E>() -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        Self(store: store.clone())
    }

    /// Returns an independent copy with storage of the given capacity (direct column).
    ///
    /// - Precondition: `capacity >= count`
    /// - Complexity: O(`count`)
    @inlinable
    public func clone<E>(capacity: Index_Primitives.Index<E>.Count) -> Self
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        Self(store: store.clone(capacity: capacity))
    }
}

// ============================================================================
// MARK: - Spans
// ============================================================================

extension Array where S: ~Copyable {
    /// Mutable span of the array elements (direct column; form-α method).
    @inlinable
    @_lifetime(&self)
    public mutating func mutableSpan<E: ~Copyable>() -> Swift.MutableSpan<E>
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        store.mutableSpan
    }

    /// Calls `body` with a read-only span over the elements (`Shared` column; scoped at
    /// the class hop).
    @inlinable
    public func withSpan<E, R, Failure: Swift.Error>(
        _ body: (Swift.Span<E>) throws(Failure) -> R
    ) throws(Failure) -> R
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear> {
        try store.withSpan(body)
    }

    /// Calls `body` with a mutable span (`Shared` column; uniqueness restored FIRST).
    @inlinable
    public mutating func withMutableSpan<E, R, Failure: Swift.Error>(
        _ body: (inout Swift.MutableSpan<E>) throws(Failure) -> R
    ) throws(Failure) -> R
    where S == Shared<E, Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear> {
        try store.withMutableSpan(body)
    }
}

// The read-only span on span-vending columns is the `Span.Protocol` witness:
// see `Array.Conformances.swift`.

// ============================================================================
// MARK: - Buffer Access (Escape Hatch for C Interop; direct column)
// ============================================================================

@_spi(Unsafe)
extension Array where S: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<E, R, Failure: Swift.Error>(
        _ body: (UnsafeBufferPointer<E>) throws(Failure) -> R
    ) throws(Failure) -> R
    where S == Buffer<Storage<Memory.Allocator<Memory.Heap>.System>.Contiguous<E>>.Linear {
        try unsafe store.withUnsafeBufferPointer(body)
    }
}
