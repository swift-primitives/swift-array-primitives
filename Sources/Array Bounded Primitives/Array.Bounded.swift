public import Collection_Primitives
public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Safe Element Access (Copyable elements only)

extension Array.Bounded where Element: Copyable {
    /// Returns the element at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the element to access.
    /// - Returns: The element at the index, or `nil` if out of bounds.
    @inlinable
    public func element(at index: Array<Element>.Index) -> Element? {
        guard index < count else { return nil }
        return unsafe _cachedPtr[index.position.rawValue]
    }
}

extension Array.Bounded where Element: Copyable {
    /// Returns element at index offset from given base index.
    ///
    /// - Parameters:
    ///   - base: The starting index.
    ///   - offset: The signed offset from the base.
    /// - Returns: The element at the computed position, or `nil` if out of bounds.
    @inlinable
    public func element(at base: Array<Element>.Index, offsetBy offset: Array<Element>.Offset) -> Element? {
        guard let newIndex = base + offset else { return nil }
        guard newIndex < count else { return nil }
        return unsafe _cachedPtr[newIndex.position.rawValue]
    }
}
