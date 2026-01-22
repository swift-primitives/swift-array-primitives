// ===----------------------------------------------------------------------===//
// EXPERIMENT: noncopyable-sequence-protocol-test
// ===----------------------------------------------------------------------===//
//
// PURPOSE: Test if Sequence.Protocol (from swift-sequence-primitives) works
//          with ~Copyable array types, unlike Swift.Sequence.
//
// ===----------------------------------------------------------------------===//

import Sequence_Primitives  // Module uses underscores

struct Token: ~Copyable {
    var id: Int
}

// Test with ~Copyable element
let ptr = UnsafeMutablePointer<Token>.allocate(capacity: 2)
ptr.initialize(to: Token(id: 1))
(ptr + 1).initialize(to: Token(id: 2))

let bounded = Array<Token>.Bounded(storage: ptr, count: 2)
print("~Copyable: count = \(bounded.count)")
print("~Copyable: [0].id = \(bounded[0].id)")
print("~Copyable: [1].id = \(bounded[1].id)")

// Test with Copyable element (should use Sequence.Protocol)
let ptrInt = UnsafeMutablePointer<Int>.allocate(capacity: 3)
ptrInt.initialize(to: 10)
(ptrInt + 1).initialize(to: 20)
(ptrInt + 2).initialize(to: 30)

let boundedInt = Array<Int>.Bounded(storage: ptrInt, count: 3)
print("\nCopyable: count = \(boundedInt.count)")

// Use Sequence.Protocol's makeIterator
var iter = boundedInt.makeIterator()
print("Copyable: iterating via Sequence.Protocol...")
while let element = iter.next() {
    print("  element: \(element)")
}

print("\n✅ SUCCESS: Sequence.Protocol works with ~Copyable array types!")
