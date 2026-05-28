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

public import Array_Primitives_Core
public import Buffer_Linear_Small_Primitives
public import Collection_Primitives
public import Iterable
public import Iterator_Chunk_Primitives
public import Sequence_Primitives

// ============================================================================
// MARK: - Protocol Conformances
// ============================================================================

// Collection.Protocol conformance is inherited through Collection.Bidirectional.

// MARK: Collection.Access.Random Conformance

extension Array.Small: Collection.Access.Random where Element: Copyable {}

// MARK: Collection.Remove.Last Conformance

extension Array.Small: Collection.Remove.Last where Element: ~Copyable {}

// MARK: Collection.Clearable Conformance

extension Array.Small: Collection.Clearable where Element: ~Copyable {}

// Note: Array.Small cannot conform to Swift.Collection because it is unconditionally
// ~Copyable (has deinit for inline storage cleanup). Swift.Collection requires Self: Copyable.

// ============================================================================
// MARK: - Nested Types
// ============================================================================

// MARK: Iterator

extension Array.Small where Element: Copyable {
    /// Iterator for Array.Small elements.
    ///
    /// Delegates to the buffer's iterator for zero-copy iteration.
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linear.Small<inlineCapacity>.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Linear.Small<inlineCapacity>.Iterator) {
            self._inner = _inner
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _inner.nextSpan(maximumCount: maximumCount)
        }

        @inlinable
        public mutating func next() -> Element? {
            _inner.next()
        }
    }
}

extension Array.Small.Iterator: Sendable where Element: Sendable {}

// MARK: Sequence.Protocol Conformance

extension Array.Small: Sequence.`Protocol` where Element: Copyable {
    /// Returns an iterator over the array elements.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(_inner: _buffer.makeIterator())
    }
}

// MARK: Iterable Conformance

// Dual conformer (`Sequence.Protocol` + `Iterable`): both declare `associatedtype Iterator`,
// split with `@_implements(Iterable, Iterator)`. Iterable → backing buffer's bulk
// `Iterator.Chunk` (memory→Iterable bridge); Sequence → the scalar `Array.Small.Iterator`.
extension Array.Small: Iterable where Element: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Chunk<Element>

    @_lifetime(borrow self)
    @inlinable
    public borrowing func makeIterator() -> Iterator_Primitive.Iterator.Chunk<Element> {
        _buffer.makeIterator()
    }
}

// ============================================================================
// MARK: - Sendable Conformance
// ============================================================================

extension Array.Small: @unchecked Sendable where Element: Sendable {}
