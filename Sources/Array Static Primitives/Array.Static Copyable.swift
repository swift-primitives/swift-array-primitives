//
//  File.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 24/01/2026.
//

public import Array_Primitives_Core
public import Index_Primitives


// MARK: - Safe Element Access (Copyable elements only)

extension Array.Static where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < _count else { return nil }
        return unsafe _storage.read(at: index.position.rawValue).pointee
    }
}

extension Array.Static where Element: Copyable {
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
        guard let newIndex = base + offset else { return nil }
        guard newIndex < _count else { return nil }
        return unsafe _storage.read(at: newIndex.position.rawValue).pointee
    }
}

extension Array.Static where Element: Copyable {
    /// Accesses the element at the given typed index (copy semantics for Copyable elements).
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public subscript(index: Index) -> Element {
        get {
            precondition(index < _count, "Index out of bounds")
            return unsafe _storage.read(at: index.position.rawValue).pointee
        }
        set {
            precondition(index < _count, "Index out of bounds")
            unsafe _storage.pointer(at: index.position.rawValue).pointee = newValue
        }
    }
}
