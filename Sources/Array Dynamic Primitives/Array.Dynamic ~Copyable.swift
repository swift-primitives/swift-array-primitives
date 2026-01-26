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

// ============================================================================
// MARK: - Collection Conformances
// ============================================================================

// MARK: Collection.Indexed

extension Array: Collection.Indexed where Element: ~Copyable {
    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(count) }

    @inlinable
    public func index(after i: Index) -> Index { (i + 1)! }
}

// MARK: Collection.Bidirectional

extension Array: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { (i - 1)! }
}

// ============================================================================
// MARK: - Properties
// ============================================================================

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

// ============================================================================
// MARK: - Subscripts
// ============================================================================

// MARK: Index Subscript

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

// ============================================================================
// MARK: - Element Access
// ============================================================================

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

// ============================================================================
// MARK: - Mutating Operations
// ============================================================================

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

// ============================================================================
// MARK: - Span Access
// ============================================================================

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
            return unsafe Swift.Span(_unsafeStart: _cachedPtr.base, count: count)
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
            return unsafe MutableSpan(_unsafeStart: _cachedPtr.base, count: count)
        }
    }
}

// ============================================================================
// MARK: - Buffer Access
// ============================================================================

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
            return try unsafe body(UnsafeBufferPointer(start: _cachedPtr.base, count: count))
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
            return try unsafe body(UnsafeMutableBufferPointer(start: _cachedPtr.base, count: count))
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}

// ============================================================================
// MARK: - Property Views
// ============================================================================

// MARK: ForEach Property View

extension Array where Element: ~Copyable {
    /// Property view for iteration operations.
    ///
    /// Provides iteration patterns for ALL element types including `~Copyable`:
    /// - `.forEach { }` — Borrowing iteration via `callAsFunction`
    /// - `.forEach.borrowing { }` — Explicit borrowing iteration
    ///
    /// For `Copyable` elements only:
    /// - `.forEach.consuming { }` — Consuming iteration (clears array)
    ///
    /// ## Example
    ///
    /// ```swift
    /// var array = Array<Int>()
    /// array.append(1)
    /// array.append(2)
    /// array.append(3)
    ///
    /// // Borrowing iteration (works for ALL elements)
    /// array.forEach { print($0) }
    ///
    /// // Consuming iteration (Copyable elements only)
    /// array.forEach.consuming { print($0) }
    /// // array is now empty
    /// ```
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

// MARK: ForEach: Borrowing Operations (~Copyable)

extension Property.View.Typed
where Tag == Sequence.ForEach, Base == Array<Element>, Element: ~Copyable {
    /// Borrowing iteration: `.forEach { }`
    ///
    /// Iterates over all elements without consuming them.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each borrowed element.
    @inlinable
    public func callAsFunction(_ body: (borrowing Element) -> Void) {
        let count = unsafe base.pointee.storage.header
        guard count > 0 else { return }
        unsafe base.pointee.storage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                unsafe body(elements[i])
            }
        }
    }

    /// Explicit borrowing iteration: `.forEach.borrowing { }`
    ///
    /// Same as `callAsFunction`, but with explicit naming for clarity.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each borrowed element.
    @inlinable
    public func borrowing(_ body: (borrowing Element) -> Void) {
        callAsFunction(body)
    }
}

// MARK: Drain Property View

extension Array where Element: ~Copyable {
    /// Property view for draining operations.
    ///
    /// Provides `.drain { }` via `callAsFunction`, which removes all elements
    /// from the array and passes each to the closure with ownership.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// After draining, the array is empty but still usable.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var array = Array<Int>()
    /// array.append(1)
    /// array.append(2)
    /// array.append(3)
    ///
    /// // Drain all elements (takes ownership)
    /// array.drain { element in
    ///     process(element)
    /// }
    /// // array is now empty but still usable
    /// array.append(4)
    /// ```
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View.Typed<Element> {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View.Typed<Element>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View.Typed<Element>(&self)
            yield &view
        }
    }
}

// MARK: Drain: Operations (~Copyable)

extension Property.View.Typed
where Tag == Sequence.Drain, Base == Array<Element>, Element: ~Copyable {
    /// Drain iteration: `.drain { }`
    ///
    /// Removes all elements from the array, passing each to the closure
    /// with ownership. After this call, the array is empty but usable.
    /// Works for ALL element types including `~Copyable`.
    ///
    /// - Parameter body: A closure called with each element (consuming).
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        let count = unsafe base.pointee.storage.header
        guard count > 0 else { return }
        unsafe base.pointee.storage.withUnsafeMutablePointerToElements { elements in
            for i in 0..<count {
                unsafe body((elements + i).move())
            }
        }
        unsafe base.pointee.storage.header = 0
    }
}
