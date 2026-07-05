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
public import Array_Protocol_Primitives
public import Buffer_Linear_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
public import Span_Protocol_Primitives
public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives

// ============================================================================
// MARK: - Institute Collection Conformances (chained through the COLUMN)
// ============================================================================

// Collection.Protocol / Bidirectional / Array.Protocol are declared — with the lattice
// rationale — in `Array ~Copyable.swift`.

// NO element bound (Audit-#5 relaxation, W5-1 — see `Array ~Copyable.swift`).
// Restates the seam bound alongside `Span.Protocol` so the random-access witnesses
// resolve to the seam-bound implementations, not the Span-gated defaults (finding
// shared across the W1 clusters).
extension __Array: Collection.Access.Random
where S: Span.`Protocol` & Store.`Protocol` & Buffer.`Protocol` & ~Copyable {}

// Collection.Remove.Last: WITHDRAWN at the W4 reshape. Its generic witness would mutate
// through the seam without per-column CoW pinning; the semantic `pop()` (gated,
// generic) and the column-pinned growth ops replace it. Re-admit if the protocol gains
// a gate-aware default.

// ============================================================================
// MARK: - Dynamic typealias
// ============================================================================

extension __Array where S: ~Copyable {
    public typealias Dynamic = Self
}

// ============================================================================
// MARK: - Span.Protocol (span-vending columns) → Iterable bridge → Sequenceable
// ============================================================================
//
// The conformances chain through the COLUMN: every span-vending column conforms to
// `Span.Protocol`, so the ADT forwards. Since shared-primitives c27eaa7 (W5, the
// lifetime-laundered span across the box hop) the `Shared` column conforms too —
// `Array<Shared<E, B>>` joins this whole lattice with no array-side code.

extension __Array: Span.`Protocol` where S: Span.`Protocol` & ~Copyable {
    /// Read-only span of the array elements, forwarded from the column.
    @inlinable
    public var span: Swift.Span<S.Element> {
        @_lifetime(borrow self)
        borrowing get {
            store.span
        }
    }
}

// Iterable — the multipass borrowing `makeIterator()` is vended by the memory→Iterable
// bridge over the Span.`Protocol` conformance above, yielding `Iterator.Chunk` (which
// admits ~Copyable elements — D4; no element bound per the Audit-#5 relaxation).
extension __Array: Iterable where S: Span.`Protocol` & ~Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<S.Element>
}

// `S.Iterator: Escapable` makes the forwarded iterator returnable from the consuming
// `makeIterator()` without a lifetime annotation rooted in (consumed) `self`; both
// ratified columns' iterators are Escapable values.
extension __Array: Sequenceable where S: Sequenceable & ~Copyable, S.Iterator: Escapable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = S.Iterator

    @inlinable
    public consuming func makeIterator() -> S.Iterator {
        take().makeIterator()
    }
}
