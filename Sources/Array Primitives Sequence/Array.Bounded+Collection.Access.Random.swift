public import Collection_Primitives
public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Iterator

extension Array.Bounded where Element: Copyable {
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
        var position: Index_Primitives.Index<Element>

        @usableFromInline @unsafe
        init(base: UnsafePointer<Element>, count: Index_Primitives.Index<Element>.Count) {
            unsafe self.base = base
            self.end = count
            self.position = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard position < end else { return nil }
            let result = unsafe base[position.rawValue.rawValue]
            position = (position + 1)!
            return result
        }
    }
}

extension Array.Bounded.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Bounded: Sequence.`Protocol` where Element: Copyable {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        unsafe Iterator(base: UnsafePointer(storage), count: .init(__unchecked: _count.rawValue))
    }
}

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Bounded: Collection.`Protocol` where Element: Copyable {}

// MARK: - Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided in +Collection.Indexed.swift
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

extension Array.Bounded: Collection.Access.Random where Element: Copyable {}
