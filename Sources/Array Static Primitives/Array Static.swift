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
import Index_Primitives
import Sequence_Primitives

// ============================================================================
// MARK: - Protocol Conformances
// ============================================================================

// MARK: Collection.Protocol Conformance

extension Array.Static: Collection.`Protocol` {}

// MARK: Collection.Access.Random Conformance

extension Array.Static: Collection.Access.Random {}

// Note: Array.Static cannot conform to Swift.Collection because it is unconditionally
// ~Copyable (has deinit for inline storage cleanup). Swift.Collection requires Self: Copyable.

// MARK: Collection.Remove.Last Conformance

extension Array.Static: Collection.Remove.Last {}

// MARK: Collection.Clearable Conformance

extension Array.Static: Collection.Clearable {}

// ============================================================================
// MARK: - Nested Types
// ============================================================================

// MARK: Iterator

extension Array.Static {
    /// Pointer-based iterator for Array.Static.
    ///
    /// Zero-copy iteration using typed `Index<Element>` for position tracking.
    /// The iterator holds a pointer to the inline storage.
    ///
    /// ## Safety
    ///
    /// The iterator is only valid while the source array exists and is not mutated.
    /// Since Array.Static uses inline storage that moves with the struct, the
    /// iterator must be used within the same scope where it was created.
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
            self.base = base
            self.end = count
            self.position = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard position < end else { return nil }
            let result = unsafe base[position]
            position = position + Index.Count.one
            return result
        }
    }
}

extension Array.Static.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: Sequence.Protocol Conformance

extension Array.Static: Sequence.`Protocol` {
    /// Returns a pointer-based iterator over the array elements.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let count = _buffer.count
        guard count > .zero else {
            return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)
        }
        let span = _buffer.span
        return unsafe Iterator(base: span.unsafeBaseAddress!, count: count)
    }
}

// MARK: Error

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
