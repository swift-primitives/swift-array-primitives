// ===----------------------------------------------------------------------===//
// EXPERIMENT: Test if Iterator in main file + conformance in separate file works
// ===----------------------------------------------------------------------===//

import Sequence_Primitives

public enum Array<Element: ~Copyable>: ~Copyable {

    public struct Bounded: ~Copyable {
        @usableFromInline
        var storage: UnsafeMutablePointer<Element>

        public let count: Int

        public init(storage: UnsafeMutablePointer<Element>, count: Int) {
            self.storage = storage
            self.count = count
        }

        deinit {
            for i in 0..<count {
                (storage + i).deinitialize(count: 1)
            }
            if count > 0 {
                storage.deallocate()
            }
        }

        // Direct subscript for all element types
        public subscript(position: Int) -> Element {
            _read { yield storage[position] }
        }
    }
}

// Iterator defined in SAME file as Bounded
extension Array.Bounded where Element: Copyable {
    public struct Iterator: IteratorProtocol {
        let elements: [Element]
        var index: Int = 0

        public init(elements: [Element]) {
            self.elements = elements
            self.index = 0
        }

        public mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }
}
