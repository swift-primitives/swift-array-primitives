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
public import Array_Fixed_Primitive
public import Storage_Heap_Primitives
public import Array_Protocol_Primitives
public import Buffer_Linear_Bounded_Primitives
public import Collection_Primitives
import Index_Primitives
public import Sequence_Primitives

// MARK: - Sequenceable (single-pass, consuming, Copyable-only)
//
// Buffer.Linear.Bounded.Scalar backs Sequenceable. No Swift.Sequence: the iteration
// family is ~Copyable end-to-end. (Span.`Protocol` + Iterable — the
// multipass borrowing surface — moved to `Array.Fixed ~Copyable.swift` (Piece 7a / D4),
// relaxed to `~Copyable`.)

extension Array.Fixed: Sequenceable where Element: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Buffer<Storage<Element>.Heap>.Linear.Bounded.Scalar

    @inlinable
    public consuming func makeIterator() -> Buffer<Storage<Element>.Heap>.Linear.Bounded.Scalar {
        _buffer.makeIterator()
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

extension Array.Fixed where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(_ index: Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            return _buffer[index]
        }
        set {
            precondition(index < count, "Index out of bounds")
            _buffer[index] = newValue
        }
    }
}

// MARK: - CoW-aware MutableSpan (Copyable elements)

extension Array.Fixed where Element: Copyable {
    /// Mutable span with copy-on-write semantics.
    ///
    /// Forwards `Buffer.Linear.Bounded`'s form-α `mutableSpan()` *method* (D1).
    @inlinable
    public var mutableSpan: Swift.MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _buffer.mutableSpan()
        }
    }
}

extension Array.Fixed where Element: Copyable {
    /// Returns element at index offset from given base index.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = try? (base + offset) else { return nil }
        guard newIndex < count else { return nil }
        return _buffer[newIndex]
    }
}

// MARK: - Safe Element Access (Copyable elements only)

extension Array.Fixed where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        return _buffer[index]
    }
}
