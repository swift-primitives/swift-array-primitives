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
public import Array_Static_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Storage_Heap_Primitives
public import Array_Protocol_Primitives
public import Buffer_Linear_Inline_Primitives
public import Collection_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
public import Sequence_Primitives
public import Span_Protocol_Primitives
public import Memory_Iterator_Primitives
import Index_Primitives

// ============================================================================
// MARK: - Institute Collection Conformances
// ============================================================================

// Collection.Protocol conformance is inherited through Collection.Bidirectional.

extension Array.Static: Collection.Access.Random where Element: ~Copyable {}

extension Array.Static: Collection.Remove.Last where Element: ~Copyable {}

extension Array.Static: Collection.Clearable where Element: ~Copyable {}

// ============================================================================
// MARK: - Iterable (~Copyable) + Sequenceable (Copyable elements)
// ============================================================================
//
// Re-uses Iterator.Chunk (multipass, borrowing, over the inline buffer span) +
// Buffer.Linear.Inline.Scalar (single-pass, consuming), mirroring buffer-linear's
// Inline variant. No Swift.Sequence (Static is unconditionally ~Copyable).

// Span.`Protocol` exposes the inline buffer's span so the
// memory→Iterable bridge can vend `Iterator.Chunk`. RELAXED to `~Copyable` (Piece 7b):
// Array.Static conforms Collection.Access.Random (-> Collection.Bidirectional ->
// Collection.Protocol: Iterable) where Element: ~Copyable, so its Iterable must hold for
// ~Copyable too. The inline buffer's span carries ~Copyable elements.
extension Array.Static: Span.`Protocol` where Element: ~Copyable {
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get { _buffer.span }
    }
}

// Iterable — multipass borrowing `makeIterator()` vended FOR FREE by the
// memory→Iterable bridge over Span.`Protocol`, yielding Iterator.Chunk.
extension Array.Static: Iterable where Element: ~Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<Element>
}

extension Array.Static: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Inline<capacity>.Scalar

    @inlinable
    public consuming func makeIterator() -> Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear.Inline<capacity>.Scalar {
        _buffer.makeIterator()
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// ============================================================================
// MARK: - Error
// ============================================================================

extension Array.Static.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "static array is full"
        case .indexOutOfBounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        }
    }
}
