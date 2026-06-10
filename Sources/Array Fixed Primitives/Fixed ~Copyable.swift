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
public import Array_Fixed_Primitive
public import Array_Protocol_Primitives
public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Span_Protocol_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
// Internal: supplies the memory→Iterable bridge default that witnesses `makeIterator()`
// for the Span.Protocol-bridged Iterable conformance below (load-bearing for conformance
// synthesis; not referenced from public/inlinable signatures).
import Memory_Iterator_Primitives

// ============================================================================
// MARK: - Collection Conformances (the span-bridged lattice; mirrors Array<S>)
// ============================================================================
//
// NO element bound (Audit-#5 relaxation, W5-1 — see `Array ~Copyable.swift`):
// the lattice protocols admit `~Copyable` elements; witnesses read borrowing.

extension Fixed: Collection.`Protocol` where S: Span.`Protocol` & ~Copyable {}

extension Fixed: Collection.Access.Random where S: Span.`Protocol` & ~Copyable {}

extension Fixed: Collection.Bidirectional where S: Span.`Protocol` & ~Copyable {}

// The hoisted protocol name (`__ArrayProtocol`): `Array.Protocol` is namespaced under the
// column-generic `Array<S>`, which a top-level conformance clause cannot bind.
extension Fixed: __ArrayProtocol where S: Span.`Protocol` & ~Copyable {}

extension Fixed: Span.`Protocol` where S: Span.`Protocol` & ~Copyable {
    /// Read-only span of the elements, forwarded from the column.
    @inlinable
    public var span: Swift.Span<S.Element> {
        @_lifetime(borrow self)
        borrowing get {
            store.span
        }
    }
}

// No element bound — the D4 bridge vends `Iterator.Chunk` for both element kinds.
extension Fixed: Iterable where S: Span.`Protocol` & ~Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<S.Element>
}

// ============================================================================
// MARK: - Properties (generic)
// ============================================================================

extension Fixed where S: ~Copyable {
    /// The number of elements — by the always-full invariant, equal to `capacity`.
    @inlinable
    public var count: Index.Count { store.count }

    /// Whether the array is empty (only a zero-capacity column).
    @inlinable
    public var isEmpty: Bool { store.isEmpty }

    /// The total capacity of the array.
    @inlinable
    public var capacity: Index.Count { store.capacity }

    /// Always zero — the always-full invariant.
    @inlinable
    public var freeCapacity: Index.Count {
        store.capacity.subtract.saturating(store.count)
    }
}

// ============================================================================
// MARK: - Element Access (generic: the seam subscript, gated)
// ============================================================================

extension Fixed where S: ~Copyable {
    /// Accesses the element at the given typed index. The mutating access runs the
    /// column's semantic mutation gate first (CoW-correct on `Shared`-wrapped columns).
    ///
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
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing S.Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(store[index])
    }
}

extension Fixed where S: ~Copyable, S.Element: Copyable {
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
// MARK: - Mutation (generic; the always-full set: in-place only)
// ============================================================================

extension Fixed where S: ~Copyable {
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
}
