// ===----------------------------------------------------------------------===//
// EXPERIMENT: noncopyable-multifile-poisoning
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Having `extension Array.Bounded: Sequence where Element: Copyable`
//             in a SEPARATE file causes "type 'Element' does not conform to
//             protocol 'Copyable'" errors on UnsafeMutablePointer<Element> in
//             Array.swift.
//
// METHODOLOGY: [EXP-004a] Incremental Construction (multi-file)
//
// STATUS: TBD
// RESULT: TBD
//
// ===----------------------------------------------------------------------===//

struct Token: ~Copyable {
    var id: Int
}

// Test with ~Copyable element
let ptr = UnsafeMutablePointer<Token>.allocate(capacity: 2)
ptr.initialize(to: Token(id: 1))
(ptr + 1).initialize(to: Token(id: 2))

let bounded = Array<Token>.Bounded(storage: ptr, count: 2)
print("Bounded with ~Copyable: count = \(bounded.count)")
print("Element[0].id = \(bounded.storage[0].id)")
print("Element[1].id = \(bounded.storage[1].id)")

// Test with Copyable element (direct access, no Sequence)
let ptrInt = UnsafeMutablePointer<Int>.allocate(capacity: 3)
ptrInt.initialize(to: 10)
(ptrInt + 1).initialize(to: 20)
(ptrInt + 2).initialize(to: 30)

let boundedInt = Array<Int>.Bounded(storage: ptrInt, count: 3)
print("\nBounded with Copyable: count = \(boundedInt.count)")
print("Direct access:")
for i in 0..<boundedInt.count {
    print("  element[\(i)]: \(boundedInt.storage[i])")
}

print("\n✅ Multi-file experiment PASSED!")
print("Base types compile without Sequence conformance")
