public import Collection_Primitives

// MARK: - Iterator

extension Array.Unbounded where Element: Copyable {
    /// Iterator for Array.Unbounded that copies elements for safe iteration.
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

extension Array.Unbounded.Iterator: Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Unbounded: Sequence.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        var elements: [Element] = []
        let elementCount = self.count
        elements.reserveCapacity(elementCount)
        for i in 0..<elementCount {
            elements.append(_storage._readElement(at: i))
        }
        return Iterator(elements: elements)
    }
}

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Unbounded: Collection.`Protocol` where Element: Copyable {}

// MARK: - Collection.Bidirectional Conformance
// Note: index(before:) defined in Collection.Indexed_Bidirectional conformance

extension Array.Unbounded: Collection.Bidirectional where Element: Copyable {}

// MARK: - Collection.Access.Random Conformance

extension Array.Unbounded: Collection.Access.Random where Element: Copyable {}
