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

// Note: Array.Bounded is declared INSIDE the Array enum body (in Array.swift)
// due to Swift's ~Copyable constraint propagation rules. This file contains
// only extensions to Array.Bounded.

public import Index_Primitives

// MARK: - Properties

extension Array.Bounded {
    /// The number of elements in the array.
    @inlinable
    public var count: Index_Primitives.Index<Element>.Count { _count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == .zero }
}

// MARK: - Initialization (Checked)

extension Array.Bounded {
    /// Creates a fixed array with the specified count, initializing each element.
    ///
    /// - Parameters:
    ///   - count: The number of elements.
    ///   - initializer: A closure that provides the element for each index.
    /// - Throws: `Error.invalidCount` if count is negative.
    @inlinable
    public init(
        count: Int,
        initializingWith initializer: (Int) -> Element
    ) throws(Error) {
        guard count >= 0 else {
            throw .invalidCount(count)
        }

        if count == 0 {
            self._storage = Array.Storage.createEmpty()
            unsafe self._cachedPtr = _storage._elementsPointer
            self._count = .zero
            return
        }

        self._storage = Array.Storage.create(capacity: count, initializingWith: initializer)
        unsafe self._cachedPtr = _storage._elementsPointer
        self._count = Index_Primitives.Index<Element>.Count(__unchecked: count)
    }
}

// MARK: - Initialization (Unchecked)

extension Array.Bounded {
    /// Creates a fixed array with the specified count without validation.
    ///
    /// Use this when the count has already been validated by an invariant.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter indicating unchecked operation.
    ///   - count: The number of elements. Must be non-negative.
    ///   - initializer: A closure that provides the element for each index.
    /// - Precondition: `count >= 0`
    @inlinable
    public init(
        __unchecked: Void,
        count: Int,
        initializingWith initializer: (Int) -> Element
    ) {
        precondition(count >= 0, "Count must be non-negative")

        if count == 0 {
            self._storage = Array.Storage.createEmpty()
            unsafe self._cachedPtr = _storage._elementsPointer
            self._count = .zero
            return
        }

        self._storage = Array.Storage.create(capacity: count, initializingWith: initializer)
        unsafe self._cachedPtr = _storage._elementsPointer
        self._count = Index_Primitives.Index<Element>.Count(__unchecked: count)
    }
}

// MARK: - Span Access (Normative)

extension Array.Bounded where Element: ~Copyable {
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
            unsafe Span(_unsafeStart: _cachedPtr, count: _count.rawValue)
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
            unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _count.rawValue)
        }
    }
}

// MARK: - CoW-aware MutableSpan (Copyable elements)

extension Array.Bounded where Element: Copyable {
    /// Mutable span with copy-on-write semantics.
    ///
    /// This shadows the base `mutableSpan` when `Element: Copyable`,
    /// ensuring the storage is unique before mutation.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            makeUnique()
            return unsafe MutableSpan(_unsafeStart: _cachedPtr, count: _count.rawValue)
        }
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension Array.Bounded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe _cachedPtr = _storage._elementsPointer
        }
    }
}

// MARK: - Pointer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Array.Bounded where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeBufferPointer(start: _count.rawValue > 0 ? _cachedPtr : nil, count: _count.rawValue))
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
        try unsafe body(UnsafeMutableBufferPointer(start: _count.rawValue > 0 ? _cachedPtr : nil, count: _count.rawValue))
    }
}

// MARK: - Borrowed Element Access (for ~Copyable elements)

extension Array.Bounded where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// This method provides borrowed access to elements, enabling safe read access
    /// to move-only types without consuming them.
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Index_Primitives.Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < _count, "Index out of bounds")
        return unsafe body((_cachedPtr + index.position.rawValue).pointee)
    }

    /// Iterates over all elements in the array.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<_count.rawValue {
            unsafe body((_cachedPtr + i).pointee)
        }
    }
}

// MARK: - Error

extension Array.Bounded {
    /// Errors that can occur during bounded array operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The requested count is invalid (negative).
        case invalidCount(Int)

        /// The index is out of bounds.
        case indexOutOfBounds(index: Index_Primitives.Index<Element>, count: Index_Primitives.Index<Element>.Count)
    }
}
