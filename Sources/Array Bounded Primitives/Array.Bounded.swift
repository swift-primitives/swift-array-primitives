public import Collection_Primitives
public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Iterator

extension Array.Bounded {
    /// Pointer-based iterator for Array.Bounded.
    ///
    /// Zero-copy iteration using typed `Index<Element>` for position tracking.
    /// The iterator holds a pointer to the storage, not a copy of the elements.
    ///
    /// ## Safety
    ///
    /// The iterator is only valid while the source array exists and is not mutated.
    /// This matches the semantics of stdlib's Array.Iterator.
    @safe
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let base: UnsafePointer<Element>

        @usableFromInline
        let end: Index_Primitives.Index<Element>.Count

        @usableFromInline
        var index: Index_Primitives.Index<Element>

        @usableFromInline @unsafe
        init(base: UnsafePointer<Element>, count: Index_Primitives.Index<Element>.Count) {
            unsafe self.base = base
            self.end = count
            self.index = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < end else { return nil }
            let result = unsafe base[index.position.rawValue]
            index = (index + 1)!
            return result
        }
    }
}

extension Array.Bounded.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Bounded: Sequence.`Protocol` {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    @inlinable
    public borrowing func makeIterator() -> Array.Bounded.Iterator {
        unsafe Iterator(base: UnsafePointer(_cachedPtr), count: .init(__unchecked: _count.rawValue))
    }
}

// MARK: - Swift.Sequence Conformance
//
// Bridge to Swift.Sequence for `for-in` loops and stdlib algorithms.
// Requires explicit underestimatedCount to resolve ambiguity with
// Sequence.Protocol+Swift.Sequence default implementation.

extension Array.Bounded: Swift.Sequence where Element: Copyable {
    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { _count.rawValue }
}

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Bounded: Collection.`Protocol` {}

// MARK: - Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided in +Collection.Indexed.swift
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

extension Array.Bounded: Collection.Access.Random {}

// MARK: - Swift.Collection Conformance
// Bridge to Swift standard library collections for interop with stdlib algorithms.
// Requirements satisfied by Collection.Protocol conformance above.

extension Array.Bounded: Swift.Collection where Element: Copyable {}
extension Array.Bounded: Swift.BidirectionalCollection where Element: Copyable {}
extension Array.Bounded: Swift.RandomAccessCollection where Element: Copyable {}

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
