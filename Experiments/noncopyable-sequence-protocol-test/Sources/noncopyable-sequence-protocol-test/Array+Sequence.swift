// ===----------------------------------------------------------------------===//
// Test: Sequence.Protocol conformance in SEPARATE file
//       BUT Iterator is defined in main file
// ===----------------------------------------------------------------------===//

import Sequence_Primitives

// Sequence.Protocol conformance - conformance in separate file
// Iterator already defined in Array.swift
extension Array.Bounded: Sequence.`Protocol` where Element: Copyable {
    public func makeIterator() -> Iterator {
        var elements: [Element] = []
        for i in 0..<count {
            elements.append(storage[i])
        }
        return Iterator(elements: elements)
    }
}
