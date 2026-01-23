public import Array_Primitives_Core
public import Sequence_Primitives
public import Index_Primitives

// MARK: - Iterator

extension Array.Static {
    /// Pointer-based iterator for Array.Inline.
    ///
    /// Zero-copy iteration using typed `Index<Element>` for position tracking.
    /// The iterator holds a pointer to the inline storage.
    ///
    /// ## Safety
    ///
    /// The iterator is only valid while the source array exists and is not mutated.
    /// Since Array.Inline uses inline storage that moves with the struct, the
    /// iterator must be used within the same scope where it was created.
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

extension Array.Static.Iterator: @unchecked Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Static: Sequence.`Protocol` {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    ///
    /// ## Note
    ///
    /// Array.Inline uses inline storage. The iterator captures a pointer to
    /// element 0, which is valid for the duration of this borrow.
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        // Get pointer to first element (or a valid pointer if empty)
        if _count.rawValue > 0 {
            let basePtr = unsafe _storage.read(at: 0)
            return unsafe Iterator(base: basePtr, count: .init(__unchecked: _count.rawValue))
        } else {
            // Empty array - pointer is irrelevant, count is zero
            return unsafe Iterator(base: UnsafePointer<Element>(bitPattern: 1)!, count: .zero)
        }
    }
}
