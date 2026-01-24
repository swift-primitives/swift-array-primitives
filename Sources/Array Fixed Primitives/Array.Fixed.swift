public import Array_Primitives_Core
public import Index_Primitives
import Sequence_Primitives

// MARK: - Properties

extension Array.Fixed {
    /// Whether the array is empty.
    @inlinable
    public var isEmpty: Bool { count == .zero }
}

// MARK: - Sequence.Protocol Conformance

extension Array.Fixed: Sequence.`Protocol` {
    /// Returns a pointer-based iterator over the array elements.
    ///
    /// Zero-copy iteration - no allocation, no element copying.
    /// Uses typed `Index<Element>` for position tracking.
    @inlinable
    public borrowing func makeIterator() -> Array.Fixed.Iterator {
        unsafe Iterator(base: UnsafePointer(_cachedPtr), count: .init(__unchecked: count.rawValue))
    }
}

// MARK: - Iterator

extension Array.Fixed {
    /// Pointer-based iterator for Array.Fixed.
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
        let end: Index.Count

        @usableFromInline
        var index: Index

        @usableFromInline @unsafe
        init(base: UnsafePointer<Element>, count: Index.Count) {
            unsafe self.base = base
            self.end = count
            self.index = .zero
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < end else { return nil }
            let result = unsafe base[index]
            index = (index + 1)!
            return result
        }
    }
}

extension Array.Fixed.Iterator: @unchecked Sendable where Element: Sendable {}







