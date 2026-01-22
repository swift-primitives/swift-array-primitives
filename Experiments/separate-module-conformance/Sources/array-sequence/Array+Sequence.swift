// ===----------------------------------------------------------------------===//
// EXPERIMENT: separate-module-conformance - ArraySequence Module
// ===----------------------------------------------------------------------===//
//
// PURPOSE: Add retroactive Sequence.Protocol conformance from a separate module.
//
// HYPOTHESIS: Module boundaries might isolate constraint environments.
//
// NOTE: Using custom Sequence.Protocol (not Swift.Sequence) because
//       Swift.Sequence requires Self: Copyable.
//
// ===----------------------------------------------------------------------===//

import ArrayCore
public import Sequence_Primitives

// MARK: - Iterator (for Copyable elements only)

extension Array.Bounded where Element: Copyable {
    /// Iterator that copies elements for safe iteration.
    public struct Iterator: IteratorProtocol {
        var elements: [Element]
        var index: Int = 0

        init(elements: [Element]) {
            self.elements = elements
        }

        public mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }
}

// MARK: - Sequence.Protocol Conformance

/// Retroactive Sequence.Protocol conformance for Copyable elements.
///
/// This conformance is in a SEPARATE MODULE from the type definition
/// to test if module boundaries prevent constraint poisoning.
///
/// Using Sequence.Protocol (from Sequence_Primitives) instead of Swift.Sequence
/// because Swift.Sequence requires Self: Copyable.
extension Array.Bounded: Sequence.`Protocol` where Element: Copyable {
    public borrowing func makeIterator() -> Iterator {
        var elements: [Element] = []
        elements.reserveCapacity(count)
        for i in 0..<count {
            elements.append(self[i])
        }
        return Iterator(elements: elements)
    }
}
