// ===----------------------------------------------------------------------===//
// EXPERIMENT: conditional-copyable-type
// ===----------------------------------------------------------------------===//
//
// PURPOSE: Test if making Array.Bounded conditionally Copyable enables
//          Sequence conformance without constraint poisoning.
//
// HYPOTHESIS: If Array.Bounded is Copyable when Element is Copyable,
//             then Sequence conformance (which requires Self: Copyable)
//             might work because the type IS Copyable for that constraint.
//
// PROBLEM: Array.Bounded has a deinit, which makes it unconditionally ~Copyable.
//          We need a variant without deinit to test this hypothesis.
//
// STATUS: [PENDING]
// RESULT: [PENDING]
//
// ===----------------------------------------------------------------------===//

// MARK: - Test Type

struct Token: ~Copyable {
    var id: Int
}

// MARK: - Array Definition (NO deinit, to allow conditional Copyable)

/// A test array type that can be conditionally Copyable.
///
/// Note: This type does NOT have a deinit, so it leaks memory!
/// This is intentional for the experiment - we want to test
/// whether conditional Copyable enables Sequence conformance.
public enum TestArray<Element: ~Copyable>: ~Copyable {

    public struct Bounded: ~Copyable {
        var storage: UnsafeMutablePointer<Element>
        public let count: Int

        public init(count: Int, initializer: (Int) throws -> Element) rethrows {
            if count == 0 {
                unsafe self.storage = UnsafeMutablePointer<Element>(bitPattern: 1)!
                self.count = 0
                return
            }

            let storage = UnsafeMutablePointer<Element>.allocate(capacity: count)
            for i in 0..<count {
                try unsafe (storage + i).initialize(to: initializer(i))
            }
            unsafe self.storage = storage
            self.count = count
        }

        public subscript(position: Int) -> Element {
            _read {
                precondition(position >= 0 && position < count, "Index out of bounds")
                yield unsafe storage[position]
            }
        }

        public func forEach(_ body: (borrowing Element) -> Void) {
            for i in 0..<count {
                body(unsafe storage[i])
            }
        }

        // NO deinit - this is intentional to test conditional Copyable
    }
}

// MARK: - Conditional Copyable (CRITICAL: Must be in same file as type)

extension TestArray.Bounded: Copyable where Element: Copyable {}

// MARK: - Iterator for Copyable elements

extension TestArray.Bounded where Element: Copyable {
    public struct Iterator: IteratorProtocol {
        var base: TestArray<Element>.Bounded
        var index: Int = 0

        public mutating func next() -> Element? {
            guard index < base.count else { return nil }
            defer { index += 1 }
            return base[index]
        }
    }
}

// MARK: - Sequence Conformance (only valid when Bounded is Copyable)

extension TestArray.Bounded: Sequence where Element: Copyable {
    public func makeIterator() -> Iterator {
        Iterator(base: self)
    }
}

// MARK: - Tests

func testNoncopyableElements() {
    print("=== Test 1: ~Copyable Elements ===")

    let tokens = TestArray<Token>.Bounded(count: 3) { Token(id: $0) }

    print("count: \(tokens.count)")
    print("tokens[0].id: \(tokens[0].id)")
    print("tokens[1].id: \(tokens[1].id)")
    print("tokens[2].id: \(tokens[2].id)")

    print("forEach:", terminator: " ")
    tokens.forEach { token in
        print(token.id, terminator: " ")
    }
    print()

    print("✅ ~Copyable elements work\n")
}

func testCopyableWithSequence() {
    print("=== Test 2: Copyable Elements with Sequence Conformance ===")

    let numbers = TestArray<Int>.Bounded(count: 5) { $0 * 10 }

    print("count: \(numbers.count)")

    // for-in via Sequence conformance
    print("for-in loop:", terminator: " ")
    for n in numbers {
        print(n, terminator: " ")
    }
    print()

    // Standard Sequence methods
    let sum = numbers.reduce(0, +)
    print("reduce sum: \(sum)")

    let mapped = numbers.map { $0 * 2 }
    print("mapped: \(mapped)")

    print("✅ Sequence conformance works\n")
}

// MARK: - Main

print(String(repeating: "=", count: 60))
print("EXPERIMENT: Conditional Copyable Type")
print(String(repeating: "=", count: 60))
print()

testNoncopyableElements()
testCopyableWithSequence()

print(String(repeating: "=", count: 60))
print("RESULTS")
print(String(repeating: "=", count: 60))
print("""

If you see this message, BOTH tests passed:
1. TestArray<~Copyable>.Bounded works (no constraint poisoning)
2. Sequence conformance works (enabled by conditional Copyable)

CONDITIONAL COPYABLE APPROACH:
- TestArray.Bounded is ~Copyable by default
- TestArray.Bounded: Copyable where Element: Copyable
- Sequence conformance requires Self: Copyable
- When Element: Copyable, Self IS Copyable, so Sequence works!

CRITICAL LIMITATION:
- This only works because TestArray.Bounded has NO deinit
- With a deinit, the type is unconditionally ~Copyable
- Array.Bounded/Inline/Small all have deinits (required for cleanup)
- Array.Unbounded uses ManagedBuffer and can be conditionally Copyable

""")
