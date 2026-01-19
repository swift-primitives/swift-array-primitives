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
    /// A non-resizable array that is always fully initialized.
    ///
    /// Unlike standard `Array`, `Bounded` cannot grow or shrink after creation.
    /// All elements are initialized at construction time.
    @safe
    public struct Bounded: ~Copyable {
        @usableFromInline
        var storage: UnsafeMutablePointer<Element>

        /// The number of elements in the array.
        public let count: Int

        deinit {
            for i in 0..<count {
                unsafe (storage + i).deinitialize(count: 1)
            }
            if count > 0 {
                unsafe storage.deallocate()
            }
        }
    }
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
            // Use global sentinel for empty arrays - provides defense in depth over bitPattern
            unsafe self.storage = _emptyContainerSentinel.assumingMemoryBound(to: Element.self)
            self.count = 0
            return
        }

        let storage = UnsafeMutablePointer<Element>.allocate(capacity: count)
        for i in 0..<count {
            unsafe (storage + i).initialize(to: initializer(i))
        }
        unsafe self.storage = storage
        self.count = count
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
            unsafe self.storage = _emptyContainerSentinel.assumingMemoryBound(to: Element.self)
            self.count = 0
            return
        }

        let storage = UnsafeMutablePointer<Element>.allocate(capacity: count)
        for i in 0..<count {
            unsafe (storage + i).initialize(to: initializer(i))
        }
        unsafe self.storage = storage
        self.count = count
    }
}

// MARK: - Properties

extension Array.Bounded {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { count == 0 }
}

// MARK: - Subscript

extension Array.Bounded {
    /// Accesses the element at the specified index.
    @inlinable
    public subscript(index: Int) -> Element {
        _read {
            precondition(index >= 0 && index < count, "Index out of bounds")
            yield unsafe storage[index]
        }
        _modify {
            precondition(index >= 0 && index < count, "Index out of bounds")
            yield &(unsafe storage[index])
        }
    }
}

// MARK: - Element Access (Checked)

extension Array.Bounded {
    /// Accesses the element at the specified index.
    ///
    /// - Parameter index: The index of the element to access.
    /// - Returns: The element at the index.
    /// - Throws: `Error.indexOutOfBounds` if the index is invalid.
    @inlinable
    public func element(at index: Int) throws(Error) -> Element {
        guard index >= 0 && index < count else {
            throw .indexOutOfBounds(index: index, count: count)
        }
        return unsafe storage[index]
    }

    /// Updates the element at the specified index.
    ///
    /// - Parameters:
    ///   - index: The index of the element to update.
    ///   - body: A closure that receives an inout reference to the element.
    /// - Throws: `Error.indexOutOfBounds` if the index is invalid.
    @inlinable
    public mutating func update(
        at index: Int,
        _ body: (inout Element) throws -> Void
    ) throws(Error) {
        guard index >= 0 && index < count else {
            throw .indexOutOfBounds(index: index, count: count)
        }
        try! unsafe body(&storage[index])
    }
}

// MARK: - Element Access (Unchecked)

extension Array.Bounded {
    /// Updates the element at the specified index without bounds checking.
    ///
    /// Use this when the index has already been validated by an invariant.
    ///
    /// - Parameters:
    ///   - __unchecked: Marker parameter indicating unchecked operation.
    ///   - index: The index of the element to update. Must be in `0..<count`.
    ///   - body: A closure that receives an inout reference to the element.
    /// - Precondition: `index >= 0 && index < count`
    @inlinable
    public mutating func update<E: Swift.Error>(
        __unchecked index: Int,
        _ body: (inout Element) throws(E) -> Void
    ) throws(E) {
        precondition(index >= 0 && index < count, "Index out of bounds")
        try unsafe body(&storage[index])
    }
}

// MARK: - Span Access (Normative)

extension Array.Bounded {
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
            // Note: storage is always non-nil (sentinel pointer for empty case)
            unsafe Span(_unsafeStart: storage, count: count)
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
            // Note: storage is always non-nil (sentinel pointer for empty case)
            unsafe MutableSpan(_unsafeStart: storage, count: count)
        }
    }
}

// MARK: - Pointer Access (Escape Hatch)

extension Array.Bounded {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(UnsafeBufferPointer(start: count > 0 ? storage : nil, count: count))
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
        try unsafe body(UnsafeMutableBufferPointer(start: count > 0 ? storage : nil, count: count))
    }
}

// MARK: - Sendable

extension Array.Bounded: @unchecked Sendable where Element: Sendable {}

// MARK: - Error

extension Array.Bounded {
    /// Errors that can occur during bounded array operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The requested count is invalid (negative).
        case invalidCount(Int)

        /// The index is out of bounds.
        case indexOutOfBounds(index: Int, count: Int)
    }
}
