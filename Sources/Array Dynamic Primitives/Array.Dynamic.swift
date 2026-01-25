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

// MARK: Collection.Protocol Conformance

extension Array: Collection.`Protocol` where Element: Copyable {}

// MARK: Collection.Access.Random Conformance

extension Array: Collection.Access.Random where Element: Copyable {}

// MARK: Swift.Collection Conformances
// Bridge to Swift standard library collections for interop with stdlib algorithms.

extension Array: Swift.Sequence where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { count.rawValue }
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
    /// Pointer-based iterator for Array.
    ///
    /// Zero-copy iteration using typed `Index<Element>` for position tracking.
    /// The iterator holds a pointer to the storage, not a copy of the elements.
    ///
    /// ## Safety
    ///
    /// The iterator is only valid while the source array exists and is not mutated.
    /// This matches the semantics of stdlib's Array.Iterator.
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let base: UnsafePointer<Element>

        @usableFromInline
        let end: Index.Count

        @usableFromInline
        var position: Index

        @usableFromInline @unsafe
        init(base: UnsafePointer<Element>, count: Index.Count) {
            unsafe self.base = base
            self.end = count
            self.position = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard position < end else { return nil }
            let result = unsafe base[position]
            position = (position + 1)!
            return result
        }
    }
}

extension Array.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: Sequence.Protocol Conformance

extension Array: Sequence.`Protocol` where Element: Copyable {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        unsafe Iterator(base: UnsafePointer(_cachedPtr), count: .init(__unchecked: count.rawValue))
    }
}

// ============================================================================
// MARK: - Sendable Conformance
// ============================================================================

// Note: Array Sendable conformance is defined in Array Primitives Core
// because it requires access to the struct definition.
