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
import Index_Primitives
public import Property_Primitives
import Range_Primitives
import Sequence_Primitives

// ============================================================================
// MARK: - Collection Conformances
// ============================================================================

// MARK: Collection.Indexed

extension Array.Static: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(count) }

    @inlinable
    public func index(after i: Index) -> Index { i + Index.Count.one }
}

// MARK: Collection.Bidirectional

extension Array.Static: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { try! (i - Index.Offset.one) }
}

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Static where Element: ~Copyable {
    /// The number of elements in the array.
    @inlinable
    public var count: Index.Count {
        _buffer.count
    }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// Whether the array is at full capacity.
    @inlinable
    public var isFull: Bool { _buffer.isFull }
}

// ============================================================================
// MARK: - Subscripts
// ============================================================================

// MARK: Index Subscript

extension Array.Static where Element: ~Copyable {
    /// Accesses the element at the given typed index.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        @_lifetime(borrow self)
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

extension Array.Static where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_buffer[index])
    }
}

// ============================================================================
// MARK: - Mutating Operations
// ============================================================================

extension Array.Static where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// - Parameter element: The element to append (consumed).
    /// - Throws: ``Array.Static.Error.overflow`` if the array is full.
    @inlinable
    public mutating func append(_ element: consuming Element) throws(Array.Static.Error) {
        if let overflow = _buffer.append(element) {
            _ = consume overflow
            throw .overflow
        }
    }

    /// Removes and returns the last element.
    ///
    /// - Returns: The removed element, or `nil` if the array is empty.
    @inlinable
    public mutating func removeLast() -> Element? {
        guard !_buffer.isEmpty else { return nil }
        return _buffer.removeLast()
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll() {
        guard _buffer.count > .zero else { return }
        _buffer.removeAll()
    }
}

// ============================================================================
// MARK: - Span Access
// ============================================================================

extension Array.Static where Element: ~Copyable {
    /// Provides read-only span access to the array elements.
    @inlinable
    public func withSpan<R, E: Swift.Error>(
        _ body: (Swift.Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        try body(_buffer.span)
    }

    /// Provides mutable span access to the array elements.
    @inlinable
    public mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (borrowing MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        try body(_buffer.mutableSpan)
    }
}

// ============================================================================
// MARK: - Buffer Access
// ============================================================================

@_spi(Unsafe)
extension Array.Static where Element: ~Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let span = _buffer.span
        let count = Int(bitPattern: _buffer.count)
        return try unsafe body(UnsafeBufferPointer(start: count > 0 ? span.unsafeBaseAddress : nil, count: count))
    }

    /// Provides mutable access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = Int(bitPattern: _buffer.count)
        let span = _buffer.mutableSpan
        let ptr = count > 0 ? unsafe UnsafeMutablePointer(mutating: span.unsafeBaseAddress!) : nil
        return try unsafe body(UnsafeMutableBufferPointer(start: ptr, count: count))
    }
}

// ============================================================================
// MARK: - Property Views
// ============================================================================

// MARK: ForEach Property View

extension Array.Static where Element: ~Copyable {
    /// Property view for iteration operations.
    @inlinable
    public var forEach: Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity>(&self)
            yield &view
        }
    }
}

// MARK: ForEach: Borrowing Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Static<n>, Element: ~Copyable {
    /// Borrowing iteration: `.forEach { }`
    @inlinable
    public func callAsFunction(_ body: (borrowing Element) -> Void) {
        let count = unsafe base.pointee._buffer.count
        guard count > .zero else { return }
        for i in 0..<Int(bitPattern: count) {
            let slot = Index_Primitives.Index<Element>(Ordinal(UInt(i)))
            body(unsafe base.pointee._buffer[slot])
        }
    }

    /// Explicit borrowing iteration: `.forEach.borrowing { }`
    @inlinable
    public func borrowing(_ body: (borrowing Element) -> Void) {
        callAsFunction(body)
    }
}

// MARK: Drain Property View

extension Array.Static where Element: ~Copyable {
    /// Property view for draining operations.
    @inlinable
    public var drain: Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity>(&self)
            yield &view
        }
    }
}

// MARK: Drain: Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.Drain, Base == Array<Element>.Static<n>, Element: ~Copyable {
    /// Drain iteration: `.drain { }`
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        let count = unsafe base.pointee._buffer.count
        guard count > .zero else { return }
        while !unsafe base.pointee._buffer.isEmpty {
            body(unsafe base.pointee._buffer.consumeFront())
        }
    }
}
