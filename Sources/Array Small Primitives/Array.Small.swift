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
public import Array_Small_Primitive
public import Storage_Heap_Primitives
public import Array_Protocol_Primitives
public import Buffer_Linear_Small_Primitives
public import Collection_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
public import Sequence_Primitives
public import Span_Protocol_Primitives
public import Memory_Iterator_Primitives

// ============================================================================
// MARK: - Institute Collection Conformances
// ============================================================================

// Collection.Protocol conformance is inherited through Collection.Bidirectional.

extension Array.Small: Collection.Access.Random where Element: Copyable {}

extension Array.Small: Collection.Remove.Last where Element: ~Copyable {}

extension Array.Small: Collection.Clearable where Element: ~Copyable {}

// ============================================================================
// MARK: - Iterable (~Copyable) + Sequenceable (Copyable elements)
// ============================================================================
//
// Re-uses Iterator.Chunk (multipass, borrowing, over the small-vec buffer span) +
// Buffer.Linear.Small.Scalar (single-pass, consuming), mirroring buffer-linear's
// Small variant. No Swift.Sequence (Small is unconditionally ~Copyable).

// Span.`Protocol` exposes the small-vec buffer's span so the
// memory→Iterable bridge can vend `Iterator.Chunk`. RELAXED to `~Copyable` (Piece 7b):
// Array.Small conforms Collection.Bidirectional (-> Collection.Protocol: Iterable) where
// Element: ~Copyable, so its Iterable must hold for ~Copyable too. The ~Copyable span exists.
extension Array.Small: Span.`Protocol` where Element: ~Copyable {}

// Iterable — multipass borrowing `makeIterator()` vended FOR FREE by the
// memory→Iterable bridge over Span.`Protocol`, yielding Iterator.Chunk.
extension Array.Small: Iterable where Element: ~Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<Element>
}

extension Array.Small: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Buffer<Storage<Element>.Heap>.Linear.Small<inlineCapacity>.Scalar

    @inlinable
    public consuming func makeIterator() -> Buffer<Storage<Element>.Heap>.Linear.Small<inlineCapacity>.Scalar {
        _buffer.makeIterator()
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// ============================================================================
// MARK: - Sendable Conformance
// ============================================================================

extension Array.Small: @unchecked Sendable where Element: Sendable {}
