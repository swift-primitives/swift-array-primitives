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
public import Index_Primitives
public import Property_Primitives
public import Range_Primitives
public import Sequence_Primitives

// ============================================================================
// MARK: - Subscripts
// ============================================================================

extension Array.Static where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
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

// ============================================================================
// MARK: - Element Access
// ============================================================================

extension Array.Static where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        return _buffer[index]
    }
}

extension Array.Static where Element: Copyable {
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

// ============================================================================
// MARK: - Property View Operations
// ============================================================================

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Static<n>, Element: Copyable {
    /// Consuming iteration: `.forEach.consuming { }`
    @_lifetime(&self)
    @inlinable
    public mutating func consuming(_ body: (Element) -> Void) {
        let count = unsafe base.pointee._buffer.count
        guard count > .zero else { return }
        for i in 0..<Int(bitPattern: count) {
            let slot = Index_Primitives.Index<Element>(Ordinal(UInt(i)))
            body(unsafe base.pointee._buffer[slot])
        }
        unsafe base.pointee._buffer.removeAll()
    }
}
