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

// Note: Array.Inline is declared INSIDE the Array enum body (in Array.swift)
// due to a Swift compiler bug where nested types with value generic parameters
// declared in extensions do not properly inherit ~Copyable constraints from
// the outer type. This file contains only extensions to Array.Inline.

// MARK: - Properties

extension Array.Inline where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Int { _count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { _count >= capacity }
}

// MARK: - Core Operations

extension Array.Inline where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append (consumed).
    /// - Throws: ``Array/Inline/Error/overflow`` if the array is full.
    @inlinable
    public mutating func append(_ element: consuming Element) throws(Array.Inline.Error) {
        guard _count < capacity else {
            throw .overflow
        }
        let ptr = unsafe _pointerToElement(at: _count)
        unsafe ptr.initialize(to: element)
        _count += 1
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard _count > 0 else { return nil }
        _count -= 1
        let ptr = unsafe _pointerToElement(at: _count)
        return unsafe ptr.move()
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll() {
        guard _count > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<_count {
                let elementPtr = unsafe (basePtr + i * stride)
                    .assumingMemoryBound(to: Element.self)
                unsafe elementPtr.deinitialize(count: 1)
            }
        }
        _count = 0
    }
}

// MARK: - Subscript Access (Copyable elements only)

extension Array.Inline where Element: Copyable {
    /// Accesses the element at the specified index.
    ///
    /// - Parameter index: The index of the element.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public subscript(index: Int) -> Element {
        get {
            precondition(index >= 0 && index < _count, "Index out of bounds")
            return unsafe _readPointerToElement(at: index).pointee
        }
        set {
            precondition(index >= 0 && index < _count, "Index out of bounds")
            let ptr = unsafe _pointerToElement(at: index)
            unsafe ptr.pointee = newValue
        }
    }
}

// MARK: - Borrowed Element Access (for ~Copyable elements)

extension Array.Inline where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    ///
    /// - Parameters:
    ///   - index: The index of the element.
    ///   - body: A closure that receives a borrowed reference to the element.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withElement<R>(at index: Int, _ body: (borrowing Element) -> R) -> R {
        precondition(index >= 0 && index < _count, "Index out of bounds")
        return unsafe body(_readPointerToElement(at: index).pointee)
    }

    /// Iterates over all elements in the array.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let stride = MemoryLayout<Element>.stride
        try unsafe withUnsafePointer(to: _elements) { storagePtr throws(E) in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            for i in 0..<_count {
                let elementPtr = unsafe (basePtr + i * stride)
                    .assumingMemoryBound(to: Element.self)
                try unsafe body(elementPtr.pointee)
            }
        }
    }

    /// Removes and consumes all elements.
    ///
    /// - Parameter body: A closure that receives each consumed element.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard _count > 0 else { return }
        let stride = MemoryLayout<Element>.stride
        unsafe Swift.withUnsafeMutablePointer(to: &_elements) { storagePtr in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            for i in 0..<_count {
                let elementPtr = unsafe (basePtr + i * stride)
                    .assumingMemoryBound(to: Element.self)
                unsafe body(elementPtr.move())
            }
        }
        _count = 0
    }
}

// MARK: - Span Access

extension Array.Inline where Element: ~Copyable {
    /// Provides read-only span access to the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Note
    ///
    /// Inline storage requires closure-based access because the storage address
    /// is not stable (it moves with the struct). Use `span` property on heap-backed
    /// variants (Bounded, Unbounded) for direct access.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafePointer(to: _elements) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe Span(_unsafeStart: elementPtr, count: _count)
            return try body(span)
        }
    }

    /// Provides mutable span access to the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - No concurrent mutable borrows are permitted.
    /// - Violating this contract is undefined behavior.
    ///
    /// ## Note
    ///
    /// Inline storage requires closure-based access because the storage address
    /// is not stable (it moves with the struct). Use `mutableSpan` property on
    /// heap-backed variants (Bounded, Unbounded) for direct access.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafeMutablePointer(to: &_elements) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: _count)
            return try body(span)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch for C Interop)

@_spi(Unsafe)
extension Array.Inline where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe withUnsafePointer(to: _elements) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            return try unsafe body(UnsafeBufferPointer(start: _count > 0 ? elementPtr : nil, count: _count))
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
        return try unsafe withUnsafeMutablePointer(to: &_elements) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            return try unsafe body(UnsafeMutableBufferPointer(start: _count > 0 ? elementPtr : nil, count: _count))
        }
    }
}

// MARK: - Error Types (Hoisted to Module Level)

/// Hoisted implementation of ``Array/Inline/Error``.
///
/// Swift does not allow nested types inside generic types to be easily accessed.
/// This error type is hoisted to module level and exposed via typealias.
public enum __ArrayInlineError: Swift.Error, Sendable, Equatable {
    /// The array is full and cannot accept more elements.
    case overflow

    /// The index is out of bounds.
    case indexOutOfBounds(index: Int, count: Int)
}

extension Array.Inline {
    /// Errors that can occur during inline array operations.
    public typealias Error = __ArrayInlineError
}

extension Array.Inline.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .overflow:
            return "inline array is full"
        case .indexOutOfBounds(let index, let count):
            return "index \(index) out of bounds for count \(count)"
        }
    }
}
