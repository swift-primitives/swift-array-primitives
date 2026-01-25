//
//  Array.Static Copyable.swift
//  swift-array-primitives
//
//  Created by Coen ten Thije Boonkkamp on 24/01/2026.
//

public import Array_Primitives_Core
public import Index_Primitives
public import Property_Primitives
public import Range_Primitives
public import Sequence_Primitives

// ============================================================================
// MARK: - ForEach: Consuming Operations (Copyable only)
// ============================================================================

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Static<n>, Element: Copyable {
    /// Consuming iteration: `.forEach.consuming { }`
    ///
    /// Iterates over all elements and then clears the array.
    /// Only available for `Copyable` elements.
    ///
    /// - Parameter body: A closure called with each element.
    @_lifetime(&self)
    @inlinable
    public mutating func consuming(_ body: (Element) -> Void) {
        let count = unsafe base.pointee.count
        (0..<count).forEach { i in
            unsafe body(base.pointee.storage.read(at: i).pointee)
        }
        unsafe base.pointee.storage.deinitialize(count: count)
        unsafe base.pointee.count = Index<Element>.Count(__unchecked: 0)
    }
}

// ============================================================================
// MARK: - Safe Element Access (Copyable elements only)
// ============================================================================

extension Array.Static where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Index) -> Element? {
        guard index < count else { return nil }
        return unsafe storage.read(at: index).pointee
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
        guard newIndex < count else { return nil }
        return unsafe storage.read(at: newIndex).pointee
    }
}

// ============================================================================
// MARK: - Typed Subscript (Copyable)
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
            return unsafe storage.read(at: index).pointee
        }
        set {
            precondition(index < count, "Index out of bounds")
            unsafe storage.pointer(at: index).pointee = newValue
        }
    }
}
