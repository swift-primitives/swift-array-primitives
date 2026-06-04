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
public import Collection_Primitives
internal import Index_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
public import Span_Protocol_Primitives
public import Memory_Iterator_Primitives
internal import Property_Primitives
internal import Sequence_Primitives

// ============================================================================
// MARK: - Collection Protocol Conformances
// ============================================================================

// MARK: - Collection.Protocol Conformance
//
// Stated explicitly rather than left implicit through the Collection.Bidirectional
// refinement (Collection.Bidirectional: Collection.`Protocol`). The
// startIndex / endIndex / index(after:) / index(before:) witnesses are provided
// once by Array.Protocol's defaults; this conformance carries Index and the subscript.
extension Array.Fixed: Collection.`Protocol` where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(_ index: Index) -> Element {
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

extension Array.Fixed: Collection.Access.Random {}

// MARK: - Collection.Bidirectional Conformance

extension Array.Fixed: Collection.Bidirectional where Element: ~Copyable {}

// MARK: Array.Protocol

extension Array.Fixed: Array.`Protocol` where Element: ~Copyable {}

// MARK: - Span.`Protocol` + Iterable (multipass, bridge-vended, ~Copyable)
//
// RELAXED to `~Copyable` (Piece 7a / D4): the span (above) carries `~Copyable` elements
// (`span[i]` borrows, never moves out), so the memory→Iterable bridge vends the bulk
// `Iterator.Chunk` for BOTH element kinds. Required for the `Collection.Protocol: Iterable`
// refine edge, since `Array.Fixed: Collection.Protocol where Element: ~Copyable`.
// (Sequenceable — single-pass, consuming, Copyable-only — stays in Array.Fixed Copyable.swift.)

extension Array.Fixed: Span.`Protocol` where Element: ~Copyable {}

extension Array.Fixed: Iterable where Element: ~Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<Element>
}

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
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

extension Array.Fixed where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_buffer[index])
    }
}

// ============================================================================
// MARK: - Buffer Access (Escape Hatch for C Interop)
// ============================================================================

@_spi(Unsafe)
extension Array.Fixed where Element: Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _buffer.withUnsafeBufferPointer(body)
    }

    /// Provides mutable access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _buffer.withUnsafeMutableBufferPointer(body)
    }
}

// ============================================================================
// MARK: - Span Access (Normative)
// ============================================================================

extension Array.Fixed where Element: ~Copyable {
    /// Read-only span of the array elements.
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            _buffer.span
        }
    }

    /// Mutable span of the array elements.
    ///
    /// Forwards `Buffer.Linear.Bounded`'s form-α `mutableSpan()` *method* (D1).
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _buffer.mutableSpan()
        }
    }
}

// ============================================================================
// MARK: - Property Views
// ============================================================================

