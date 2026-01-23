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
// the outer type. This file contains only extensions that require direct
// access to _storage.

public import Index_Primitives

// MARK: - Pointer Helpers

extension Array.Inline where Element: ~Copyable {

    /// Returns a mutable pointer to the element at the given index.
    @usableFromInline
    @unsafe
    package mutating func _pointerToElement(at index: Int) -> UnsafeMutablePointer<Element> {
        unsafe _storage.pointer(at: index)
    }

    /// Returns a read-only pointer to the element at the given index.
    @usableFromInline
    @unsafe
    package func _readPointerToElement(at index: Int) -> UnsafePointer<Element> {
        unsafe _storage.read(at: index)
    }
}

// MARK: - Operations Requiring Direct _storage Access

extension Array.Inline where Element: ~Copyable {
    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll() {
        guard _count.rawValue > 0 else { return }
        _storage.deinitialize(count: _count.rawValue)
        _count = .zero
    }

    /// Iterates over all elements in the array.
    ///
    /// - Parameter body: A closure that receives each borrowed element.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        for i in 0..<_count.rawValue {
            try unsafe body(_storage.read(at: i).pointee)
        }
    }

    /// Removes and consumes all elements.
    ///
    /// - Parameter body: A closure that receives each consumed element.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard _count.rawValue > 0 else { return }
        for i in 0..<_count.rawValue {
            body(_storage.move(at: i))
        }
        _count = .zero
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
        return try unsafe withUnsafePointer(to: _storage.raw) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe Span(_unsafeStart: elementPtr, count: _count.rawValue)
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
        return try unsafe withUnsafeMutablePointer(to: &_storage.raw) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            let span = unsafe MutableSpan(_unsafeStart: elementPtr, count: _count.rawValue)
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
        return try unsafe withUnsafePointer(to: _storage.raw) { storagePtr throws(E) -> R in
            let basePtr = unsafe UnsafeRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            return try unsafe body(UnsafeBufferPointer(start: _count.rawValue > 0 ? elementPtr : nil, count: _count.rawValue))
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
        return try unsafe withUnsafeMutablePointer(to: &_storage.raw) { storagePtr throws(E) -> R in
            let basePtr = UnsafeMutableRawPointer(storagePtr)
            let elementPtr = unsafe basePtr.assumingMemoryBound(to: Element.self)
            return try unsafe body(UnsafeMutableBufferPointer(start: _count.rawValue > 0 ? elementPtr : nil, count: _count.rawValue))
        }
    }
}
