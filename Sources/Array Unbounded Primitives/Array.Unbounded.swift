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

public import Index_Primitives
public import Array_Primitives_Core

// MARK: - Properties

extension Array where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count {
        Index_Primitives.Index<Element>.Count(__unchecked: _storage.header)
    }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header == 0 }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int { _storage.capacity }
}

// MARK: - Core Operations (Base - for ~Copyable elements)

extension Array where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append (consumed).
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        let count = _storage.header
        _ensureCapacity(count + 1)
        _storage.initialize(to: element, at: count)
        _storage.header = count + 1
    }

    /// Removes and returns the last element, or nil if empty.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    /// - Complexity: O(1).
    @inlinable
    public mutating func removeLast() -> Element? {
        let count = _storage.header
        guard count > 0 else { return nil }
        _storage.header = count - 1
        return _storage.move(at: count - 1)
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        _storage.deinitialize()
        if !keepingCapacity {
            _storage = Array.Storage.create(minimumCapacity: 0)
            unsafe (_cachedPtr = _storage.pointer(at: 0))
        }
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Array where Element: Copyable {
    /// Appends an element to the array (CoW-aware).
    ///
    /// This method shadows the base `append(_:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func append(_ element: Element) {
        makeUnique()
        let count = _storage.header
        _ensureCapacity(count + 1)
        _storage.initialize(to: element, at: count)
        _storage.header = count + 1
    }

    /// Removes and returns the last element (CoW-aware).
    ///
    /// This method shadows the base `removeLast()` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func removeLast() -> Element? {
        makeUnique()
        let count = _storage.header
        guard count > 0 else { return nil }
        _storage.header = count - 1
        return _storage.move(at: count - 1)
    }

    /// Removes all elements from the array (CoW-aware).
    ///
    /// This method shadows the base `removeAll(keepingCapacity:)` when `Element: Copyable`,
    /// providing copy-on-write semantics.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        makeUnique()
        _storage.deinitialize()
        if !keepingCapacity {
            _storage = Array.Storage.create(minimumCapacity: 0)
            unsafe (_cachedPtr = _storage.pointer(at: 0))
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
    public func withElement<R>(at index: Index_Primitives.Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return unsafe _storage.withUnsafeMutablePointerToElements { elements in
            body(unsafe (elements + index.position.rawValue).pointee)
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
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index.position.rawValue < count.rawValue else { return nil }
        return unsafe _cachedPtr[index.position.rawValue]
    }

    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(
        at base: Array<Element>.Index,
        offsetBy offset: Array<Element>.Index.Offset
    ) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex.position.rawValue < count.rawValue else { return nil }
        return unsafe _cachedPtr[newIndex.position.rawValue]
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
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            let count = _storage.header
            // _cachedPtr from ManagedBuffer is always valid; pointer irrelevant when count == 0
            return unsafe Span(_unsafeStart: _cachedPtr, count: count)
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
            let count = _storage.header
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
        let count = _storage.header
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
        let count = _storage.header
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
    public subscript(index: Array<Element>.Index) -> Element {
        _read {
            precondition(index.position.rawValue < _rawCount, "Index out of bounds")
            yield unsafe _cachedPtr[index.position.rawValue]
        }
        _modify {
            precondition(index.position.rawValue < _rawCount, "Index out of bounds")
            yield &(unsafe _cachedPtr[index.position.rawValue])
        }
    }
}

extension Array where Element: Copyable {
    /// Accesses the element at the given typed index with copy-on-write semantics.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Array<Element>.Index) -> Element {
        get {
            precondition(index.position.rawValue < _rawCount, "Index out of bounds")
            return unsafe _cachedPtr[index.position.rawValue]
        }
        set {
            makeUnique()
            precondition(index.position.rawValue < _rawCount, "Index out of bounds")
            unsafe _cachedPtr[index.position.rawValue] = newValue
        }
    }
}
