public import Collection_Primitives
public import Array_Primitives_Core

// MARK: - Iterator

extension Array.Inline where Element: Copyable {
    /// Iterator for Array.Inline that copies elements for safe iteration.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let elements: [Element]

        @usableFromInline
        var index: Int

        @usableFromInline
        init(elements: [Element]) {
            self.elements = elements
            self.index = 0
        }

        @inlinable
        public mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }
}

extension Array.Inline.Iterator: Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Inline: Sequence.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        var elements: [Element] = []
        elements.reserveCapacity(_count.rawValue)
        for i in 0..<_count.rawValue {
            elements.append(unsafe _readPointerToElement(at: i).pointee)
        }
        return Iterator(elements: elements)
    }
}

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Inline: Collection.`Protocol` where Element: Copyable {}

// MARK: - Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided in +Collection.Indexed.swift
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

extension Array.Inline: Collection.Access.Random where Element: Copyable {}
