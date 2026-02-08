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
public import Index_Primitives
public import Sequence_Primitives

// ============================================================================
// MARK: - Protocol Conformances
// ============================================================================

// MARK: Collection.Protocol Conformance

extension Array.Small: Collection.`Protocol` where Element: Copyable {}

// MARK: Collection.Access.Random Conformance

extension Array.Small: Collection.Access.Random where Element: Copyable {}

// Note: Array.Small cannot conform to Swift.Collection because it is unconditionally
// ~Copyable (has deinit for inline storage cleanup). Swift.Collection requires Self: Copyable.

// ============================================================================
// MARK: - Nested Types
// ============================================================================

// MARK: Iterator

extension Array.Small where Element: Copyable {
    /// Pointer-based iterator for Array.Small.
    ///
    /// Zero-copy iteration using typed `Index<Element>` for position tracking.
    /// The iterator holds a pointer to either inline or heap storage.
    ///
    /// ## Safety
    ///
    /// The iterator is only valid while the source array exists and is not mutated.
    /// For inline storage, the iterator must be used within the same scope where
    /// it was created (inline storage moves with the struct).
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
            position = position + Index.Count.one
            return result
        }
    }
}

extension Array.Small.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: Sequence.Protocol Conformance

extension Array.Small: Sequence.`Protocol` where Element: Copyable {
    /// Returns a pointer-based iterator over the array elements.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        guard count.rawValue > 0 else {
            return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)
        }

        if let heapState = heap {
            return unsafe Iterator(base: UnsafePointer(heapState.pointer), count: count)
        } else {
            return _inlineBuffer.withUnsafeBufferPointer { ubp in
                unsafe Iterator(base: ubp.baseAddress!, count: count)
            }
        }
    }
}

// ============================================================================
// MARK: - Sendable Conformance
// ============================================================================

extension Array.Small: @unchecked Sendable where Element: Sendable {}
