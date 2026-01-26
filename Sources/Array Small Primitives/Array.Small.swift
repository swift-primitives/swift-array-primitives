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
public import Sequence_Primitives

// ============================================================================
// MARK: - Protocol Conformances
// ============================================================================

// MARK: Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Small: Collection.`Protocol` where Element: Copyable {}

// MARK: Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided in ~Copyable.swift
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

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
        let base: Pointer<Element>

        @usableFromInline
        let end: Index.Count

        @usableFromInline
        var position: Index

        @usableFromInline @unsafe
        init(base: Pointer<Element>, count: Index.Count) {
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

extension Array.Small.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: Sequence.Protocol Conformance

extension Array.Small: Sequence.`Protocol` where Element: Copyable {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    ///
    /// ## Implementation Note
    ///
    /// This function must be `borrowing` (non-mutating) per Sequence protocol.
    /// For heap storage, we use the cached `_heapPtr` pointer directly.
    /// For inline storage, we use `withUnsafePointer(to:)` on the stored property
    /// to obtain a pointer without requiring `&self`.
    ///
    /// The `inline` accessor cannot be used here because it requires `mutating`
    /// context (needs `&self` to construct the accessor struct). See:
    /// `/Users/coen/Developer/swift-institute/Research/Non-Mutating-Accessor-Problem.md`
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        guard count.rawValue > 0 else {
            // Empty array - pointer is irrelevant, count is zero
            return unsafe Iterator(base: Pointer(UnsafePointer<Element>(bitPattern: 1)!), count: .zero)
        }

        if let heapState = heap {
            // Heap storage - use cached pointer (convert mutable to immutable)
            return unsafe Iterator(base: Pointer(UnsafePointer(heapState.pointer.base)), count: .init(__unchecked: count.rawValue))
        } else {
            // Inline storage - get pointer to first element via withUnsafePointer
            // Note: We use withUnsafePointer directly on the stored property because
            // the `inline` accessor requires mutating context (needs &self).
            _ = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                return unsafe Iterator(base: Pointer(elementPtr), count: .init(__unchecked: count.rawValue))
            }
        }
    }
}

// ============================================================================
// MARK: - Sendable Conformance
// ============================================================================

extension Array.Small: @unchecked Sendable where Element: Sendable {}
