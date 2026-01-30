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

public import Collection_Primitives
public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Swift.Sequence Conformance
//
// Bridge to Swift.Sequence for `for-in` loops and stdlib algorithms.
// Requires explicit underestimatedCount to resolve ambiguity with
// Sequence.Protocol+Swift.Sequence default implementation.

extension Array.Fixed: Swift.Sequence where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: - Swift.Collection Conformance
// Bridge to Swift standard library collections for interop with stdlib algorithms.
// Requirements satisfied by Collection.Protocol conformance above.

extension Array.Fixed: Swift.Collection where Element: Copyable {}
extension Array.Fixed: Swift.BidirectionalCollection where Element: Copyable {}
extension Array.Fixed: Swift.RandomAccessCollection where Element: Copyable {}

extension Array.Fixed where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index < count, "Index out of bounds")
            return unsafe _cachedPtr[index]
        }
        set {
            precondition(index < count, "Index out of bounds")
            unsafe _cachedPtr[index] = newValue
        }
    }
}

// MARK: - CoW-aware MutableSpan (Copyable elements)

extension Array.Fixed where Element: Copyable {
    /// Mutable span with copy-on-write semantics.
    ///
    /// This shadows the base `mutableSpan` when `Element: Copyable`,
    /// ensuring the storage is unique before mutation.
    @inlinable
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            makeUnique()
            return unsafe MutableSpan(_unsafeStart: _cachedPtr.base, count: Int(bitPattern: count))
        }
    }
}

extension Array.Fixed where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = try? (base + offset) else { return nil }
        guard newIndex < count else { return nil }
        return unsafe _cachedPtr[newIndex]
    }
}

// MARK: - Safe Element Access (Copyable elements only)

extension Array.Fixed where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        return unsafe _cachedPtr[index]
    }
}
