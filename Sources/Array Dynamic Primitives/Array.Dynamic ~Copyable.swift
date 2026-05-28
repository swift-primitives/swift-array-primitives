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
    public var endIndex: Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Index) -> Index { i.successor.saturating() }
}

// MARK: Collection.Bidirectional

extension Array: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { try! i.predecessor.exact() }
}

// MARK: Array.Protocol

extension Array: Array.`Protocol` where Element: ~Copyable {}

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index.Count {
        _buffer.count
    }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Index.Count { _buffer.capacity }
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
    public subscript(_ index: Index) -> Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield _buffer[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            yield &_buffer[index]
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
        return body(_buffer[index])
    }
}

// ============================================================================
// MARK: - Mutating Operations
// ============================================================================

extension Array where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append (consumed).
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        _buffer.append(consume element)
    }

    /// Static primitive for `Collection.Remove.Last`. Use `.remove.last()` at call sites.
    @inlinable
    public static func removeLast(_ base: inout Self) -> Element? {
        guard !base._buffer.isEmpty else { return nil }
        return base._buffer.remove.last()
    }

    /// Removes and returns the element at the given index, shifting subsequent elements left.
    ///
    /// - Parameter index: The index of the element to remove.
    /// - Returns: The removed element.
    /// - Precondition: The index must be in bounds.
    /// - Complexity: O(n) where n is the distance from `index` to the end.
    @inlinable
    public mutating func remove(at index: Index) -> Element {
        _buffer.remove(at: index)
    }

    // on remove.all() + buffer reassignment in deep @inlinable chain.

    /// Static primitive for `Collection.Clearable`. Use `.remove.all()` at call sites.
    @inlinable
    public static func removeAll(_ base: inout Self) {
        base._buffer.remove.all()
        base._buffer = Buffer<Element>.Linear(minimumCapacity: .zero)
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        _buffer.remove.all()
        if !keepingCapacity {
            _buffer = Buffer<Element>.Linear(minimumCapacity: .zero)
        }
    }
}

// ============================================================================
// MARK: - Span Access
// ============================================================================

extension Array where Element: ~Copyable {
    /// Read-only span of the array elements.
    @inlinable
    public var span: Swift.Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            _buffer.span
        }
    }

    /// Mutable span of the array elements.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        mutating get {
            _buffer.mutableSpan
        }
    }
}

// ============================================================================
// MARK: - Buffer Access
// ============================================================================

@_spi(Unsafe)
extension Array where Element: Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    ///
    /// - Warning: This is an escape hatch for C interop. Prefer `span` for safe access.
    /// - Warning: The pointer must not escape the closure scope.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _buffer.withUnsafeBufferPointer(body)
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
        try unsafe _buffer.withUnsafeMutableBufferPointer(body)
    }
}

// ============================================================================
// MARK: - Property Views
// ============================================================================

// MARK: Drain Property View

extension Array where Element: ~Copyable {
    public enum Drain {
        public typealias View = Property<Sequence.Drain, Array<Element>>.Inout.Typed<Element>
    }
}

extension Array where Element: ~Copyable {
    /// Property view for draining operations.
    @inlinable
    public var drain: Drain.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Drain.View = unsafe .init(&self)
            yield &view
        }
    }
}

// MARK: Drain: Operations (~Copyable)

extension Property.Inout.Typed
where Tag == Sequence.Drain, Base == Array<Element>, Element: ~Copyable {
    /// Drain iteration: `.drain { }`
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        while unsafe !base.value._buffer.isEmpty {
            body(base.value._buffer.remove.first())
        }
    }
}
