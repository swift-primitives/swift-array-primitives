// ===----------------------------------------------------------------------===//
// EXPERIMENT: wrapper-type-approach
// ===----------------------------------------------------------------------===//
//
// PURPOSE: Test if wrapper types can provide Sequence iteration without
//          causing constraint poisoning on the base type.
//
// HYPOTHESIS: A wrapper type (IterableView) that wraps the array and conforms
//             to Sequence avoids poisoning because the conformance is on the
//             wrapper, not the base type.
//
// STATUS: [PENDING]
// RESULT: [PENDING]
//
// ===----------------------------------------------------------------------===//

// MARK: - Test Type

struct Token: ~Copyable {
    var id: Int
}

// MARK: - Array Definition (same file, no separate module)

public enum Array<Element: ~Copyable>: ~Copyable {

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

        deinit {
            for i in 0..<count {
                unsafe (storage + i).deinitialize(count: 1)
            }
            if count > 0 {
                unsafe storage.deallocate()
            }
        }
    }
}

// MARK: - Wrapper Type for Sequence Conformance (Copyable elements only)

extension Array.Bounded where Element: Copyable {
    /// A wrapper that provides Sequence conformance for Copyable elements.
    ///
    /// This approach copies elements into a Swift.Array to enable iteration.
    /// Since Array.Bounded is ~Copyable, we cannot store a reference to it.
    public struct IterableView: Sequence {
        // Store a copy of elements (not a reference to base)
        let elements: [Element]

        public struct Iterator: IteratorProtocol {
            var elements: [Element]
            var index: Int = 0

            public mutating func next() -> Element? {
                guard index < elements.count else { return nil }
                defer { index += 1 }
                return elements[index]
            }
        }

        public func makeIterator() -> Iterator {
            Iterator(elements: elements)
        }
    }

    /// Returns an iterable view for use with for-in loops.
    ///
    /// Note: This copies all elements into a Swift.Array.
    public var iterable: IterableView {
        var elements: [Element] = []
        elements.reserveCapacity(count)
        for i in 0..<count {
            elements.append(self[i])
        }
        return IterableView(elements: elements)
    }
}

// MARK: - Tests

func testNoncopyableElements() {
    print("=== Test 1: ~Copyable Elements ===")

    let tokens = Array<Token>.Bounded(count: 3) { Token(id: $0) }

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

func testCopyableWithWrapper() {
    print("=== Test 2: Copyable Elements via IterableView ===")

    let numbers = Array<Int>.Bounded(count: 5) { $0 * 10 }

    print("count: \(numbers.count)")

    // for-in via wrapper
    print("for-in via .iterable:", terminator: " ")
    for n in numbers.iterable {
        print(n, terminator: " ")
    }
    print()

    // Standard Sequence methods via wrapper
    let sum = numbers.iterable.reduce(0, +)
    print("reduce sum: \(sum)")

    let mapped = numbers.iterable.map { $0 * 2 }
    print("mapped: \(mapped)")

    print("✅ IterableView wrapper works\n")
}

// MARK: - Main

print(String(repeating: "=", count: 60))
print("EXPERIMENT: Wrapper Type Approach")
print(String(repeating: "=", count: 60))
print()

testNoncopyableElements()
testCopyableWithWrapper()

print(String(repeating: "=", count: 60))
print("RESULTS")
print(String(repeating: "=", count: 60))
print("""

If you see this message, BOTH tests passed:
1. Array<~Copyable>.Bounded works (no constraint poisoning)
2. IterableView wrapper provides Sequence conformance for Copyable elements

WRAPPER APPROACH:
- Array.Bounded does NOT conform to Sequence directly
- IterableView wrapper conforms to Sequence
- Access via .iterable property: `for x in array.iterable { }`
- Avoids constraint poisoning because conformance is on wrapper

TRADE-OFF:
- Pro: Works in same module (no multi-module setup)
- Con: Requires `.iterable` accessor, not direct `for x in array { }`

""")
