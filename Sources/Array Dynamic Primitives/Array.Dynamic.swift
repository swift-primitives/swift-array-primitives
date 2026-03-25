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

// ============================================================================
// MARK: - Protocol Conformances
// ============================================================================

// Collection.Protocol conformance is inherited through Collection.Bidirectional.

// MARK: Collection.Access.Random Conformance

extension Array: Collection.Access.Random where Element: Copyable {}

// MARK: Collection.Remove.Last Conformance

extension Array: Collection.Remove.Last where Element: ~Copyable {}

// MARK: Collection.Clearable Conformance

extension Array: Collection.Clearable where Element: ~Copyable {}

// MARK: Swift.Collection Conformances
// Bridge to Swift standard library collections for interop with stdlib algorithms.

extension Array: Swift.Sequence where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

extension Array: Swift.Collection where Element: Copyable {}
extension Array: Swift.BidirectionalCollection where Element: Copyable {}
extension Array: Swift.RandomAccessCollection where Element: Copyable {}

// ============================================================================
// MARK: - Nested Types
// ============================================================================

// MARK: Typealias

extension Array {
    public typealias Dynamic = Array_Primitives_Core.Array<Element>
}

// MARK: Iterator

extension Array where Element: Copyable {
    /// Iterator for Array that delegates to Buffer.Linear.Iterator.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linear.Iterator

        @usableFromInline
        init(_inner: Buffer<Element>.Linear.Iterator) {
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

extension Array.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: Sequence.Protocol Conformance

extension Array: Sequence.`Protocol` where Element: Copyable {
    /// Returns an iterator over the array elements.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        Iterator(_inner: _buffer.makeIterator())
    }
}

// ============================================================================
// MARK: - Sendable Conformance
// ============================================================================

// Note: Array Sendable conformance is defined in Array Primitives Core
// because it requires access to the struct definition.
