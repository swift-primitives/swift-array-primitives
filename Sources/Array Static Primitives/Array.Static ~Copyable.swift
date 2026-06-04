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
public import Array_Static_Primitive
public import Array_Protocol_Primitives
public import Collection_Primitives
import Index_Primitives
internal import Property_Primitives
import Sequence_Primitives

// ============================================================================
// MARK: - Collection Conformances
// ============================================================================

// MARK: Index navigation

extension Array.Static where Element: ~Copyable {
    public typealias Index = Array<Element>.Index
}

// MARK: Collection.Bidirectional

extension Array.Static: Collection.Bidirectional where Element: ~Copyable {}

// MARK: Array.Protocol

extension Array.Static: Array.`Protocol` where Element: ~Copyable {}

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

    /// Static primitive for `Collection.Remove.Last`. Use `.remove.last()` at call sites.
    @inlinable
    public static func removeLast(_ base: inout Self) -> Element? {
        guard !base._buffer.isEmpty else { return nil }
        return base._buffer.remove.last()
    }

    /// Static primitive for `Collection.Clearable`. Use `.remove.all()` at call sites.
    @inlinable
    public static func removeAll(_ base: inout Self) {
        guard base._buffer.count > .zero else { return }
        base._buffer.remove.all()
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
        _ body: (borrowing Swift.MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        try body(_buffer.mutableSpan)
    }
}

// ============================================================================
// MARK: - Property Views
// ============================================================================

// MARK: Sequence Tag Enums

extension Array.Static where Element: ~Copyable {
    public enum Drain {
        public typealias View = Property<Sequence.Drain, Array<Element>.Static<capacity>>.Inout.Typed<Element>.Valued<capacity>
    }
}

// MARK: Drain Property View

extension Array.Static where Element: ~Copyable {
    /// Property view for draining operations.
    @inlinable
    public var drain: Drain.View {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify {
            var view: Drain.View = unsafe .init(&self)
            yield &view
        }
    }
}

// MARK: Drain: Operations (~Copyable)

extension Property.Inout.Typed.Valued
where Tag == Sequence.Drain, Base == Array<Element>.Static<n>, Element: ~Copyable {
    /// Drain iteration: `.drain { }`
    @inlinable
    public mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        let count = base.value._buffer.count
        guard count > .zero else { return }
        while unsafe !base.value._buffer.isEmpty {
            body(base.value._buffer.remove.first())
        }
    }
}
