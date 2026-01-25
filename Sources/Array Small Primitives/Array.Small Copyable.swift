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
public import Property_Primitives
public import Sequence_Primitives

// ============================================================================
// MARK: - Collection Protocol Conformances (Copyable)
// ============================================================================

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Small: Collection.`Protocol` where Element: Copyable {}

// MARK: - Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided in ~Copyable.swift
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

extension Array.Small: Collection.Access.Random where Element: Copyable {}

// Note: Array.Small cannot conform to Swift.Collection because it is unconditionally
// ~Copyable (has deinit for inline storage cleanup). Swift.Collection requires Self: Copyable.

// ============================================================================
// MARK: - Sequence Protocol Conformances (Copyable)
// ============================================================================

// MARK: - Iterator

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
            position = (position + 1)!
            return result
        }
    }
}

extension Array.Small.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

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
            return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)
        }

        if let heapState = heap {
            // Heap storage - use cached pointer
            return unsafe Iterator(base: UnsafePointer(heapState.pointer), count: .init(__unchecked: count.rawValue))
        } else {
            // Inline storage - get pointer to first element via withUnsafePointer
            // Note: We use withUnsafePointer directly on the stored property because
            // the `inline` accessor requires mutating context (needs &self).
            _ = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
                return unsafe Iterator(base: elementPtr, count: .init(__unchecked: count.rawValue))
            }
        }
    }
}

// ============================================================================
// MARK: - ForEach: Consuming Operations (Copyable only)
// ============================================================================

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Small<n>, Element: Copyable {
    /// Consuming iteration: `.forEach.consuming { }`
    ///
    /// Iterates over all elements and then clears the array.
    /// Only available for `Copyable` elements.
    ///
    /// - Parameter body: A closure called with each element.
    @_lifetime(&self)
    @inlinable
    public mutating func consuming(_ body: (Element) -> Void) {
        let count = unsafe base.pointee.count
        guard count > .zero else { return }

        if let heapState = unsafe base.pointee.heap {
            _ = unsafe heapState.storage.withUnsafeMutablePointerToElements { elements in
                for i in 0..<count.rawValue {
                    unsafe body(elements[i])
                }
            }
            heapState.storage.deinitialize()
        } else {
            // Inline storage uses stride-based raw pointer arithmetic
            let stride = MemoryLayout<Element>.stride
            unsafe withUnsafePointer(to: base.pointee.inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                for i in 0..<count.rawValue {
                    let elementPtr = unsafe (basePtr + i * stride)
                        .assumingMemoryBound(to: Element.self)
                    unsafe body(elementPtr.pointee)
                }
            }
            unsafe base.pointee.inline.deinitialize(count: count)
        }
        unsafe base.pointee.count = .zero
    }
}

// ============================================================================
// MARK: - Safe Element Access (Copyable elements only)
// ============================================================================

extension Array.Small where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        if let heap {
            return unsafe heap.pointer[index]
        } else {
            // Use withUnsafePointer directly - inline accessor requires mutating context
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + index.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr.pointee
            }
        }
    }

    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < count else { return nil }
        if let heap {
            return unsafe heap.pointer[newIndex]
        } else {
            // Use withUnsafePointer directly - inline accessor requires mutating context
            let stride = MemoryLayout<Element>.stride
            return unsafe withUnsafePointer(to: inline) { storagePtr in
                let basePtr = unsafe UnsafeRawPointer(storagePtr)
                let elementPtr = unsafe (basePtr + newIndex.position.rawValue * stride)
                    .assumingMemoryBound(to: Element.self)
                return unsafe elementPtr.pointee
            }
        }
    }
}

// ============================================================================
// MARK: - Typed Subscript (Copyable)
// ============================================================================

extension Array.Small where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            if let heap {
                return unsafe heap.pointer[index]
            } else {
                // Use withUnsafePointer directly - inline accessor requires mutating context
                let stride = MemoryLayout<Element>.stride
                return unsafe withUnsafePointer(to: inline) { storagePtr in
                    let basePtr = unsafe UnsafeRawPointer(storagePtr)
                    let elementPtr = unsafe (basePtr + index.position.rawValue * stride)
                        .assumingMemoryBound(to: Element.self)
                    return unsafe elementPtr.pointee
                }
            }
        }
        set {
            precondition(index < count, "Index out of bounds")
            if heap != nil {
                _ = heap!.storage.move(at: index)
                heap!.storage.initialize(to: newValue, at: index)
            } else {
                unsafe inline.pointer(at: index).pointee = newValue
            }
        }
    }
}
