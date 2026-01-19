// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-standards open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-standards project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Array {
    /// A growable array with a compile-time initial capacity hint.
    ///
    /// Unlike `Bounded`, this array can grow unbounded. The generic parameter `N`
    /// specifies the initial allocation capacity when the first element is added.
    /// Subsequent growth uses a doubling strategy.
    @safe
    public struct Unbounded<let N: Int>: ~Copyable {
        @usableFromInline
        var _storage: UnsafeMutablePointer<Element>?

        @usableFromInline
        var _count: Int

        @usableFromInline
        var _capacity: Int

        /// Creates an empty growable array.
        @inlinable
        public init() {
            unsafe self._storage = nil
            self._count = 0
            self._capacity = 0
        }

        deinit {
            if let storage = unsafe _storage {
                for i in 0..<_count {
                    unsafe (storage + i).deinitialize(count: 1)
                }
                unsafe storage.deallocate()
            }
        }
    }
}

// MARK: - Properties

extension Array.Unbounded {
    /// The number of elements in the array.
    @inlinable
    public var count: Int { _count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Int { _capacity }

    /// The initial capacity hint from the generic parameter.
    @inlinable
    public var initialCapacityHint: Int { N }

}

// MARK: - Core Operations

extension Array.Unbounded {
    /// Appends an element to the array.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if _count >= _capacity {
            grow()
        }
        unsafe (_storage! + _count).initialize(to: element)
        _count += 1
    }

    /// Removes and returns the last element, or nil if empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard _count > 0 else {
            return nil
        }
        _count -= 1
        return unsafe (_storage! + _count).move()
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll() {
        guard let storage = unsafe _storage else { return }
        for i in 0..<_count {
            unsafe (storage + i).deinitialize(count: 1)
        }
        _count = 0
    }

    @usableFromInline
    mutating func grow() {
        let newCapacity = _capacity == 0 ? max(N, 1) : _capacity * 2
        let newStorage = UnsafeMutablePointer<Element>.allocate(capacity: newCapacity)

        if let oldStorage = unsafe _storage {
            unsafe newStorage.moveInitialize(from: oldStorage, count: _count)
            unsafe oldStorage.deallocate()
        }

        unsafe _storage = newStorage
        _capacity = newCapacity
    }
}

// MARK: - Iteration

extension Array.Unbounded {
    /// Iterates over all elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) throws -> Void) rethrows {
        guard let storage = unsafe _storage else { return }
        for i in 0..<_count {
            try unsafe body((storage + i).pointee)
        }
    }

    /// Removes and consumes all elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        guard let storage = unsafe _storage else { return }
        for i in 0..<_count {
            unsafe body((storage + i).move())
        }
        _count = 0
    }
}

// MARK: - Span Access (Normative, Closure-Based)

extension Array.Unbounded {
    /// Provides read-only span access to the array elements.
    ///
    /// ## Lifetime Contract
    ///
    /// - The span is valid ONLY for the duration of the closure.
    /// - The span MUST NOT be stored, returned, or allowed to escape.
    /// - Violating this contract is undefined behavior.
    ///
    /// - Parameter body: A closure that receives a span view of the elements.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        if let storage = unsafe _storage {
            let span = unsafe Span(_unsafeStart: storage, count: _count)
            return try body(span)
        } else {
            // Empty array: use stdlib Array's span for empty case
            let empty: [Element] = []
            return try body(empty.span)
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
    /// - Parameter body: A closure that receives a mutable span view of the elements.
    /// - Returns: The value returned by `body`.
    /// - Throws: The error thrown by the closure.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        if let storage = unsafe _storage {
            var span = unsafe MutableSpan(_unsafeStart: storage, count: _count)
            return try body(&span)
        } else {
            // Empty array: create empty MutableSpan using global sentinel
            let sentinel = unsafe _emptyContainerSentinel.assumingMemoryBound(to: Element.self)
            var span = unsafe MutableSpan(_unsafeStart: sentinel, count: 0)
            return try body(&span)
        }
    }
}

// MARK: - Buffer Access (Escape Hatch)

extension Array.Unbounded {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if let storage = unsafe _storage {
            return try unsafe body(UnsafeBufferPointer(start: storage, count: _count))
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
    public mutating func withUnsafeMutableBufferPointer<R, E: Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        if let storage = unsafe _storage {
            return try unsafe body(UnsafeMutableBufferPointer(start: storage, count: _count))
        } else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
    }
}

// MARK: - Sendable

extension Array.Unbounded: @unchecked Sendable where Element: Sendable {}

// MARK: - Convenience Typealiases

extension Array {
    public typealias Small1 = Unbounded<1>
    public typealias Small4 = Unbounded<4>
    public typealias Small8 = Unbounded<8>
}
