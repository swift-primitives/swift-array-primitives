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

// Public API extensions for the base Array type (growable, heap-allocated).
// Note: Array struct is declared in Array.swift to enable conditional Copyable.

public import Array_Primitives_Core
import Index_Primitives

extension Array where Element: ~Copyable {
    /// Ensures the array has capacity for at least the specified number of elements.
    @usableFromInline
    package mutating func ensureCapacity(_ minimumCapacity: Index.Count) {
        guard Index.Count.init(__unchecked: storage.capacity) < minimumCapacity else { return }

        // Growth factor 2.0, minimum capacity 4
        let newCapacity = Swift.max(minimumCapacity, storage.capacity * 2, 4)
        let newStorage = Array.Storage.create(minimumCapacity: newCapacity)
        let currentCount = storage.header

        storage.move(to: newStorage)
        newStorage.header = currentCount
        storage = newStorage
        unsafe (_cachedPtr = storage.pointer(at: .zero))  // CRITICAL: Update cached pointer
    }
}


// MARK: - Properties

extension Array where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index.Count {
        Index.Count(__unchecked: storage.header)
    }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { storage.header == 0 }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int { storage.capacity }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Array where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append (consumed).
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        let count = Index.Count(__unchecked: storage.header)
        ensureCapacity(count + 1)
        storage.initialize(to: element, at: .init(count))
        storage.header = (count + .one).rawValue
    }

    /// Removes and returns the last element, or nil if empty.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    /// - Complexity: O(1).
    @inlinable
    public mutating func removeLast() -> Element? {
        let count = storage.header
        guard count > 0 else { return nil }
        storage.header = count - 1
        return storage.move(at: .init(__unchecked: (), position: count - 1))
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        storage.deinitialize()
        if !keepingCapacity {
            storage = Array.Storage.create(minimumCapacity: 0)
            unsafe (_cachedPtr = storage.pointer(at: .zero))
        }
    }
}

// MARK: - Borrowed Element Access (for ~Copyable elements)

extension Array where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return unsafe storage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index).pointee)
        }
    }
}

// MARK: - Safe Element Access (Copyable elements only)

extension Array where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        return unsafe _cachedPtr[index]
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
        return unsafe _cachedPtr[newIndex]
    }
}

// MARK: - Span Access

extension Array where Element: ~Copyable {
    /// Read-only span of the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the borrow of `self`.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let count = storage.header
            // _cachedPtr from ManagedBuffer is always valid; pointer irrelevant when count == 0
            return unsafe Swift.Span(_unsafeStart: _cachedPtr, count: count)
        }
    }

    /// Mutable span of the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the exclusive mutable borrow.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - The returned span is lifetime-dependent; the compiler is expected to diagnose escapes.
    /// - No concurrent mutable borrows are permitted.
    /// - No mutable + immutable borrow overlap is permitted.
    /// - Violating this contract is undefined behavior.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            let count = storage.header
            // _cachedPtr from ManagedBuffer is always valid; pointer irrelevant when count == 0
            return unsafe MutableSpan(_unsafeStart: _cachedPtr, count: count)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Array where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = storage.header
        if count > 0 {
            return try unsafe body(UnsafeBufferPointer(start: _cachedPtr, count: count))
        } else {
            return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
        }
    }

    /// Provides mutable access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `mutableSpan` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = storage.header
        if count > 0 {
            return try unsafe body(UnsafeMutableBufferPointer(start: _cachedPtr, count: count))
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}

extension Array where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield unsafe _cachedPtr[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &(unsafe _cachedPtr[index])
        }
    }
}



