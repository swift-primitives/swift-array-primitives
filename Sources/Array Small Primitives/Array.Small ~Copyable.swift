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
public import Index_Primitives
public import Ordinal_Primitives
public import Property_Primitives

// ============================================================================
// MARK: - Collection Conformances
// ============================================================================

// MARK: Collection.Indexed

extension Array.Small: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Index) -> Index { i.successor.saturating() }
}

// MARK: Collection.Bidirectional

extension Array.Small: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { try! i.predecessor.exact() }
}

// MARK: Array.Protocol

extension Array.Small: Array.`Protocol` where Element: ~Copyable {}

// Note: Array.Small cannot conform to Swift.Collection because it is unconditionally
// ~Copyable (has deinit for inline storage cleanup). Swift.Collection requires Self: Copyable.

// ============================================================================
// MARK: - Properties
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// The current number of elements in the array.
    @inlinable
    public var count: Index.Count { _buffer.count }

    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// The current capacity of the array.
    @inlinable
    public var capacity: Index.Count { _buffer.capacity }

    /// Whether the array is currently using heap storage.
    @inlinable
    public var isSpilled: Bool { _buffer.isSpilled }
}

// ============================================================================
// MARK: - Subscripts
// ============================================================================

// MARK: Index Subscript

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given typed index (borrowing access for ~Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(_ index: Index) -> Element {
        _read {
            precondition(index < _buffer.count, "Index out of bounds")
            yield _buffer[index]
        }
        _modify {
            precondition(index < _buffer.count, "Index out of bounds")
            yield &_buffer[index]
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// Accesses the element at the given index via closure (for ~Copyable elements).
    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        precondition(index < _buffer.count, "Index out of bounds")
        return body(_buffer[index])
    }
}

// ============================================================================
// MARK: - Mutating Operations
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// Appends an element to the array.
    ///
    /// If the array exceeds inline capacity, elements are automatically
    /// moved to heap storage.
    @inlinable
    public mutating func append(_ element: consuming Element) {
        _buffer.append(element)
    }

    /// Static primitive for `Collection.Remove.Last`. Use `.remove.last()` at call sites.
    @inlinable
    public static func removeLast(_ base: inout Self) -> Element? {
        guard !base._buffer.isEmpty else { return nil }
        return base._buffer.remove.last()
    }

    /// Static primitive for `Collection.Clearable`. Use `.remove.all()` at call sites.
    @inlinable
    public static func removeAll(_ base: inout Self) {
        base._buffer.remove.all(keepingCapacity: false)
    }

    /// Removes all elements from the array.
    @inlinable
    public mutating func removeAll(keepingCapacity: Bool = false) {
        _buffer.remove.all(keepingCapacity: keepingCapacity)
    }
}

// ============================================================================
// MARK: - Span Access
// ============================================================================

extension Array.Small where Element: ~Copyable {
    /// A read-only view of the array's elements.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let span = _buffer.span
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// A mutable view of the array's elements.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            _buffer.mutableSpan
        }
    }
}

// ============================================================================
// MARK: - Buffer Access
// ============================================================================

@_spi(Unsafe)
extension Array.Small where Element: Copyable {
    /// Provides read-only access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let n = Int(bitPattern: _buffer.count)
        guard n > 0 else {
            return try unsafe body(UnsafeBufferPointer(start: nil, count: 0))
        }
        return try unsafe span.withUnsafeBufferPointer(body)
    }

    /// Provides mutable access to the underlying contiguous storage.
    @unsafe
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let n = Int(bitPattern: _buffer.count)
        guard n > 0 else {
            return try unsafe body(UnsafeMutableBufferPointer(start: nil, count: 0))
        }
        var ms = mutableSpan
        return try unsafe ms.withUnsafeMutableBufferPointer(body)
    }
}

// ============================================================================
// MARK: - Property Views
// ============================================================================

// MARK: Sequence Tag Enums

extension Array.Small where Element: ~Copyable {
    public enum Drain {
        public typealias View = Property<Sequence.Drain, Array<Element>.Small<inlineCapacity>>.View.Typed<Element>.Valued<inlineCapacity>
    }
}

// MARK: ForEach Property View

extension Array.Small where Element: ~Copyable {
    /// Property view for iteration operations.
    @inlinable
    public var forEach: Property<Collection.ForEach, Self>.View.Typed<Element> {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify {
            var view: Property<Collection.ForEach, Self>.View.Typed<Element> = unsafe .init(&self)
            yield &view
        }
    }
}

// MARK: Drain Property View

extension Array.Small where Element: ~Copyable {
    /// Property view for draining operations.
    @inlinable
    public var drain: Drain.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify { var view: Drain.View = unsafe .init(&self); yield &view }
    }
}

// MARK: Drain: Operations (~Copyable)

extension Property.View.Typed.Valued
where Tag == Sequence.Drain, Base == Array<Element>.Small<n>, Element: ~Copyable {
    /// Drain iteration: `.drain { }`
    @_lifetime(&self)
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        while unsafe !base.pointee._buffer.isEmpty {
            body(unsafe base.pointee._buffer.remove.first())
        }
    }
}
