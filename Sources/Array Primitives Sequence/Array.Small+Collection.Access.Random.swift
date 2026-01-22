public import Collection_Primitives
public import Array_Primitives_Core
public import Index_Primitives

// MARK: - Iterator

extension Array.Small where Element: Copyable {
    /// Pointer-based iterator for Array.Small.
    ///
    /// Zero-copy iteration using typed `Index<Element>` for position tracking.
    /// The iterator holds a pointer to either inline or heap storage.
    ///
    /// ## Safety
    ///
    /// The iterator is only valid while the source array exists and is not mutated.
    /// For inline storage, the iterator must be used within the same scope where
    /// it was created (inline storage moves with the struct).
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

extension Array.Small.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Small: Sequence.`Protocol` where Element: Copyable {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    ///
    /// ## Note
    ///
    /// Array.Small can use either inline or heap storage. The iterator captures
    /// a pointer to the appropriate storage location.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        guard _count.rawValue > 0 else {
            // Empty array - pointer is irrelevant, count is zero
            return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)
        }

        if let heapPtr = unsafe _heapPtr {
            // Heap storage - use cached pointer
            return unsafe Iterator(base: UnsafePointer(heapPtr), count: .init(__unchecked: _count.rawValue))
        } else {
            // Inline storage - get pointer to first element
            let basePtr = unsafe _inlineReadPointerToElement(at: 0)
            return unsafe Iterator(base: basePtr, count: .init(__unchecked: _count.rawValue))
        }
    }
}

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Small: Collection.`Protocol` where Element: Copyable {}

// MARK: - Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided in +Collection.Indexed.swift
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

extension Array.Small: Collection.Access.Random where Element: Copyable {}
