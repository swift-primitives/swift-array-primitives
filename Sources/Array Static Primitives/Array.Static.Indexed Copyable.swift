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

public import Index_Primitives
public import Array_Primitives_Core

// ============================================================================
// MARK: - Typed Subscript (Copyable)
// ============================================================================

extension Array.Static.Indexed where Element: Copyable {
    /// Accesses the element at the given phantom-typed index (copy semantics).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be within bounds.
    @inlinable
    public subscript(index: Index_Primitives.Index<Tag>) -> Element {
        get {
            storage[index.retag(Element.self)]
        }
        set {
            storage[index.retag(Element.self)] = newValue
        }
    }

    /// Accesses the element at the given bounded index (copy semantics).
    ///
    /// The type `Index<Tag>.Bounded<capacity>` proves `0 <= index < capacity`.
    /// **No runtime bounds check is performed.**
    ///
    /// - Parameter index: A bounded index where the type proves `0 <= index < capacity`.
    @inlinable
    public subscript(_ index: Index_Primitives.Index<Tag>.Bounded<capacity>) -> Element {
        get {
            storage[index.unbounded.retag(Element.self)]
        }
        set {
            storage[index.unbounded.retag(Element.self)] = newValue
        }
    }
}

// ============================================================================
// MARK: - Safe Element Access (Copyable elements only)
// ============================================================================

extension Array.Static.Indexed where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The phantom-typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index_Primitives.Index<Tag>) -> Element? {
        storage.element(at: index.retag(Element.self))
    }
}
