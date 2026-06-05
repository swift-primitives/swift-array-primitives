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
public import Array_Small_Primitive
public import Storage_Small_Primitives
public import Storage_Primitive
public import Buffer_Linear_Primitive
public import Array_Protocol_Primitives
public import Buffer_Linear_Small_Primitives
internal import Property_Primitives

// ============================================================================
// MARK: - Subscripts
// ============================================================================

extension Array.Small where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(_ index: Index) -> Element {
        get {
            precondition(index < _buffer.count, "Index out of bounds")
            return _buffer[index]
        }
        set {
            precondition(index < _buffer.count, "Index out of bounds")
            _buffer[index] = newValue
        }
    }
}

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array.Small where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < _buffer.count else { return nil }
        return _buffer[index]
    }

    /// Returns element at index offset from given base index.
    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> Element? {
        guard let newIndex = try? (base + offset) else { return nil }
        guard newIndex < _buffer.count else { return nil }
        return _buffer[newIndex]
    }
}
