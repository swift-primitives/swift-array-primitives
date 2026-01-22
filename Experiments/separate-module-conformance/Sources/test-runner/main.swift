// ===----------------------------------------------------------------------===//
// EXPERIMENT: separate-module-conformance - Test Runner
// ===----------------------------------------------------------------------===//
//
// PURPOSE: Verify both ~Copyable elements and Sequence.Protocol conformance work.
//
// STATUS: [PENDING]
// RESULT: [PENDING]
//
// ===----------------------------------------------------------------------===//

import ArrayCore
import ArraySequence

// MARK: - Test ~Copyable Element

struct Token: ~Copyable {
    var id: Int
}

func testNoncopyableElements() {
    print("=== Test 1: ~Copyable Elements (from ArrayCore) ===")

    let tokens = Array<Token>.Bounded(count: 3) { Token(id: $0) }

    print("count: \(tokens.count)")
    print("tokens[0].id: \(tokens[0].id)")
    print("tokens[1].id: \(tokens[1].id)")
    print("tokens[2].id: \(tokens[2].id)")

    // Borrowing forEach works for ~Copyable
    print("forEach:", terminator: " ")
    tokens.forEach { token in
        print(token.id, terminator: " ")
    }
    print()

    print("✅ ~Copyable elements work\n")
}

// MARK: - Test Copyable Elements with Sequence.Protocol

func testCopyableSequence() {
    print("=== Test 2: Copyable Elements with Sequence.Protocol (from ArraySequence) ===")

    let numbers = Array<Int>.Bounded(count: 5) { $0 * 10 }

    print("count: \(numbers.count)")

    // Sequence.Protocol doesn't give for-in syntax, so test makeIterator directly
    print("iterator loop:", terminator: " ")
    var iterator = numbers.makeIterator()
    while let n = iterator.next() {
        print(n, terminator: " ")
    }
    print()

    print("✅ Sequence.Protocol conformance works\n")
}

// MARK: - Main

print(String(repeating: "=", count: 60))
print("EXPERIMENT: Separate Module Conformance")
print(String(repeating: "=", count: 60))
print()

testNoncopyableElements()
testCopyableSequence()

print(String(repeating: "=", count: 60))
print("RESULTS")
print(String(repeating: "=", count: 60))
print("""

If you see this message, BOTH tests passed:
1. Array<~Copyable>.Bounded works (no constraint poisoning in ArrayCore)
2. Sequence.Protocol conformance works (added retroactively from ArraySequence)

This would mean: Module boundaries DO prevent constraint propagation!

""")
