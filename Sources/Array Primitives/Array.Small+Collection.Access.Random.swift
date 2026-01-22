public import Collection_Primitives

// MARK: - Iterator

extension Array.Small where Element: Copyable {
    /// Iterator for Array.Small that copies elements for safe iteration.
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

extension Array.Small.Iterator: Sendable where Element: Sendable {}

// MARK: - Sequence.Protocol Conformance

extension Array.Small: Sequence.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        var elements: [Element] = []
        elements.reserveCapacity(_count)
        if let heapStorage = _heapStorage {
            for i in 0..<_count {
                elements.append(heapStorage._readElement(at: i))
            }
        } else {
            for i in 0..<_count {
                elements.append(unsafe _inlineReadPointerToElement(at: i).pointee)
            }
        }
        return Iterator(elements: elements)
    }
}

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Small: Collection.`Protocol` where Element: Copyable {}

// MARK: - Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided in +Collection.Indexed.swift
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

extension Array.Small: Collection.Access.Random where Element: Copyable {}
