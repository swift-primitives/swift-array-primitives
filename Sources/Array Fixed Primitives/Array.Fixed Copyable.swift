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

// MARK: - Swift.Sequence Conformance

extension Array.Fixed: Swift.Sequence where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { count }
}

// MARK: - Swift.Collection Conformance

extension Array.Fixed: Swift.Collection where Element: Copyable {}
extension Array.Fixed: Swift.BidirectionalCollection where Element: Copyable {}
extension Array.Fixed: Swift.RandomAccessCollection where Element: Copyable {}

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
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            _buffer.mutableSpan
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
