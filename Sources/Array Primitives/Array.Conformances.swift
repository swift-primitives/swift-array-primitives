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
public import Storage_Heap_Primitives
public import Array_Protocol_Primitives
public import Buffer_Linear_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
public import Sequence_Primitives
public import Span_Protocol_Primitives
public import Memory_Iterator_Primitives

// ============================================================================
// MARK: - Institute Collection Conformances
// ============================================================================

// Collection.Protocol is declared explicitly — with its witnesses — in `Array ~Copyable.swift`.

extension Array: Collection.Access.Random where Element: Copyable {}

extension Array: Collection.Remove.Last where Element: ~Copyable {}

extension Array: Collection.Clearable where Element: ~Copyable {}

// ============================================================================
// MARK: - Dynamic typealias
// ============================================================================

extension Array {
    public typealias Dynamic = Self
}

// ============================================================================
// MARK: - Iterable (~Copyable) + Sequenceable (Copyable elements)
// ============================================================================
//
// Re-uses Iterator.Chunk (multipass, borrowing) for `Iterable` and
// `Buffer.Linear.Scalar` (single-pass, consuming) for `Sequenceable`, mirroring
// buffer-linear. No `Swift.Sequence`: `Buffer.Linear.Scalar` is `~Copyable` and
// cannot back a Copyable stdlib `IteratorProtocol`. (The iteration family is
// `~Copyable` end-to-end at the buffer layer; array follows.)

// Span.`Protocol` exposes the span so the memory→Iterable bridge can
// vend `Iterator.Chunk`. RELAXED to `~Copyable` (Piece 7a / D4): the span carries
// `~Copyable` elements (`span[i]` borrows, never moves out), so the bridge vends the
// bulk `Iterator.Chunk` for BOTH element kinds. Required for the `Collection.Protocol:
// Iterable` refine edge, since `Array: Collection.Protocol where Element: ~Copyable`.
extension Array: Span.`Protocol` where Element: ~Copyable {}

// Iterable — the multipass borrowing `makeIterator()` is vended FOR FREE by the
// memory→Iterable bridge over the Span.`Protocol` conformance above,
// yielding `Iterator.Chunk` (no hand-written iterator). `~Copyable` per the bridge relax.
extension Array: Iterable where Element: ~Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<Element>
}

extension Array: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Buffer<Storage<Element>.Heap>.Linear.Scalar

    @inlinable
    public consuming func makeIterator() -> Buffer<Storage<Element>.Heap>.Linear.Scalar {
        _buffer.makeIterator()
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}
