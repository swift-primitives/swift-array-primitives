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
public import Collection_Primitives
public import Buffer_Linear_Small_Primitives

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
    @safe
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linear.Small<inlineCapacity>.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Linear.Small<inlineCapacity>.Iterator) {
            self._inner = _inner
        }

        @inlinable
        public mutating func next() -> Element? {
            _inner.next()
        }
    }
}

extension Array.Small.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: Sequence.Protocol Conformance

extension Array.Small: Sequence.`Protocol` where Element: Copyable {
    /// Returns an iterator over the array elements.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(_inner: _buffer.makeIterator())
    }
}

// ============================================================================
// MARK: - Sendable Conformance
// ============================================================================

extension Array.Small: @unchecked Sendable where Element: Sendable {}
