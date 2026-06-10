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
public import Buffer_Linear_Bounded_Primitives
public import Index_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
public import Span_Protocol_Primitives

// ============================================================================
// MARK: - Collection Protocol Conformances
// ============================================================================

// MARK: - Collection.Protocol Conformance
//
// Stated explicitly rather than left implicit through the Collection.Bidirectional
// refinement (Collection.Bidirectional: Collection.`Protocol`). The
// startIndex / endIndex / index(after:) / index(before:) witnesses are provided
// once by Array.Protocol's defaults; this conformance carries Index and the subscript.
extension Array.Fixed: Collection.`Protocol` where S: ~Copyable {
    public typealias Index = Index_Primitives.Index<S.Element>

    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(_ index: Index) -> S.Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield _buffer[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &_buffer[index]
        }
    }
}

// MARK: - Collection.Access.Random Conformance

extension Array.Fixed: Collection.Access.Random where S: ~Copyable {}

// MARK: - Collection.Bidirectional Conformance

extension Array.Fixed: Collection.Bidirectional where S: ~Copyable {}

// MARK: Array.Protocol

extension Array.Fixed: Array.`Protocol` where S: ~Copyable {}

// MARK: - Span.`Protocol` + Iterable (multipass, bridge-vended, ~Copyable)
//
// RELAXED to `~Copyable` (Piece 7a / D4): the span (below) carries `~Copyable` elements
// (`span[i]` borrows, never moves out), so the memory→Iterable bridge vends the bulk
// `Iterator.Chunk` for BOTH element kinds. Required for the `Collection.Protocol: Iterable`
// refine edge, since `Array.Fixed: Collection.Protocol where S: ~Copyable`.
// (Sequenceable — single-pass, consuming, Copyable-only — stays in Array.Fixed Copyable.swift.)

extension Array.Fixed: Span.`Protocol` where S: ~Copyable {}

extension Array.Fixed: Iterable where S: ~Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<S.Element>
}

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Fixed where S: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index.Count { _buffer.count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// The total capacity of the array.
    @inlinable
    public var capacity: Index.Count { _buffer.capacity }
}

// ============================================================================
// MARK: - Borrowed Element Access (for ~Copyable elements)
// ============================================================================

extension Array.Fixed where S: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing S.Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_buffer[index])
    }
}

// ============================================================================
// MARK: - Buffer Access (Escape Hatch for C Interop)
// ============================================================================

@_spi(Unsafe)
extension Array.Fixed where S: ~Copyable, S.Element: Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<S.Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _buffer.withUnsafeBufferPointer(body)
    }

    // withUnsafeMutableBufferPointer: not forwarded — the bounded buffer vends no mutable
    // pointer escape hatch (post-W3a surface); `mutableSpan` is the mutable lane.
}

// ============================================================================
// MARK: - Span Access (Normative)
// ============================================================================

extension Array.Fixed where S: ~Copyable {
    /// Read-only span of the array elements.
    @inlinable
    public var span: Swift.Span<S.Element> {
        @_lifetime(borrow self)
        borrowing get {
            _buffer.span
        }
    }

    /// Mutable span of the array elements.
    @inlinable
    public var mutableSpan: Swift.MutableSpan<S.Element> {
        @_lifetime(&self)
        mutating get {
            _buffer.mutableSpan
        }
    }
}
