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

// The COLUMN-GENERIC surface of the base Array: everything expressible through the
// seam (`Store.Protocol`: subscript/initialize/move/capacity + the `prepareForMutation()`
// gate) and the count surface (`Buffer.Protocol`) lives here ONCE, for every column.
// Semantic mutations call the gate before their first write, so the same generic body
// is copy-on-write-correct on the `Shared` column and free on the move-only columns.
// Only GROWTH and CONSTRUCTION pin per column (`Array+Columns.swift`).
public import Array_Primitive
public import Array_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Store_Protocol_Primitives
public import Span_Protocol_Primitives

// ============================================================================
// MARK: - Collection Conformances (the span-bridged lattice)
// ============================================================================
//
// `Collection.Protocol` refines `Iterable`, whose multipass borrowing iterator is
// vended by the memory→Iterable bridge over `Span.Protocol` — so the lattice holds
// exactly where the COLUMN vends a span (`S: Span.Protocol`: the direct buffer
// columns). The `Shared` column reaches its elements through the generic subscript
// and the scoped `withSpan` forms instead; its protocol-lattice membership arrives
// with a `Shared: Span.Protocol` conformance, recorded as future work.

// MARK: Collection.Protocol

extension Array: Collection.`Protocol` where S: Span.`Protocol` & ~Copyable, S.Element: Copyable {}

// MARK: Collection.Bidirectional

extension Array: Collection.Bidirectional where S: Span.`Protocol` & ~Copyable, S.Element: Copyable {}

// MARK: Array.Protocol

extension Array: Array.`Protocol` where S: Span.`Protocol` & ~Copyable, S.Element: Copyable {}

// ============================================================================
// MARK: - Properties (generic: Buffer.Protocol count + seam capacity)
// ============================================================================

extension Array where S: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index.Count {
        store.count
    }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { store.isEmpty }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Index.Count { store.capacity }

    /// The number of additional elements that can be added without reallocating.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var freeCapacity: Index.Count {
        store.capacity.subtract.saturating(store.count)
    }
}

// ============================================================================
// MARK: - Element Access (generic: the seam subscript)
// ============================================================================

extension Array where S: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// The mutating access runs the column's semantic mutation gate FIRST
    /// (`prepareForMutation()`), so in-place writes are copy-on-write-correct on the
    /// `Shared` column and free on the statically-unique columns.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(_ index: Index) -> S.Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield store[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            store.prepareForMutation()
            yield &store[index]
        }
    }

    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing S.Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(store[index])
    }
}

extension Array where S: ~Copyable, S.Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> S.Element? {
        guard index < count else { return nil }
        return store[index]
    }

    /// Returns element at index offset from given base index.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> S.Element? {
        guard let newIndex = try? (base + offset) else { return nil }
        guard newIndex < count else { return nil }
        return store[newIndex]
    }
}

// ============================================================================
// MARK: - Mutating Operations (generic: gate + seam)
// ============================================================================

extension Array where S: ~Copyable {
    /// Removes and returns the last element.
    ///
    /// - Precondition: The array must not be empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeLast() -> S.Element {
        precondition(!isEmpty, "Cannot remove from an empty array")
        store.prepareForMutation()
        let end: Index = count.map(Ordinal.init)
        let last = try! end.predecessor.exact()
        return store.move(at: last)
    }

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// - Parameter index: The index of the element to remove.
    /// - Returns: The removed element.
    /// - Precondition: The index must be in bounds.
    /// - Complexity: O(n) where n is the distance from `index` to the end.
    @inlinable
    public mutating func remove(at index: Index) -> S.Element {
        precondition(index < count, "Index out of bounds")
        store.prepareForMutation()
        let end: Index = count.map(Ordinal.init)
        let removed = store.move(at: index)
        var dst = index
        var src = dst.successor.saturating()
        while src < end {
            store.initialize(at: dst, to: store.move(at: src))
            dst = src
            src = src.successor.saturating()
        }
        return removed
    }

    /// Exchanges the elements at the two given positions.
    ///
    /// Passing the same index for both has no effect.
    ///
    /// - Precondition: Both indices must be in bounds.
    /// - Complexity: O(1)
    @inlinable
    public mutating func swap(at i: Index, with j: Index) {
        precondition(i < count && j < count, "Index out of bounds")
        guard i != j else { return }
        store.prepareForMutation()
        let a = store.move(at: i)
        let b = store.move(at: j)
        store.initialize(at: i, to: b)
        store.initialize(at: j, to: a)
    }

    /// Consumes every element front-to-back, leaving the array empty.
    ///
    /// The seam's ledger keeps `count` honest mid-drain (each `move` decrements), so the
    /// loop terminates when the column reports empty.
    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        store.prepareForMutation()
        var slot: Index = .zero
        while !isEmpty {
            body(store.move(at: slot))
            slot = slot.successor.saturating()
        }
    }
}

// ============================================================================
// MARK: - Cloning (generic on the CoW column)
// ============================================================================

extension Array where S: Copyable {
    /// Returns an independent copy of this array with its own storage.
    ///
    /// On the `Shared` (CoW) column the fresh value shares the box with `self` at the
    /// moment of copy, so running the mutation gate on it ALWAYS installs a deep copy —
    /// `clone()` never returns shared storage.
    ///
    /// - Complexity: O(`count`)
    @inlinable
    public borrowing func clone() -> Self {
        var result = copy self
        result.store.prepareForMutation()
        return result
    }
}
