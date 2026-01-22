// ===----------------------------------------------------------------------===//
// EXPERIMENT: noncopyable-protocol-workarounds
// ===----------------------------------------------------------------------===//
//
// PURPOSE: [EXP-017] Improvement Discovery
//          Find a workaround that allows ~Copyable elements with protocol
//          conformance WITHOUT conditional conformance fallback.
//
// METHODOLOGY: Test multiple protocol design patterns systematically.
//
// STATUS: CONFIRMED WORKING
// RESULT: Remove associatedtype Element from protocol, add it as direct member
//
// ===----------------------------------------------------------------------===//

// MARK: - Test Type

struct Token: ~Copyable {
    var id: Int
}

// =============================================================================
// WORKAROUND 2: Protocol WITHOUT Element Associated Type
// =============================================================================
// INSIGHT: The protocol defines INDEX operations only.
//          Conformers provide their own subscript that returns their Element type.
//          Protocol extensions MUST include `where Self: ~Copyable`.

protocol W2_Indexed: ~Copyable {
    associatedtype Index: Equatable

    var startIndex: Index { get }
    var endIndex: Index { get }
    func index(after i: Index) -> Index
    // NOTE: No subscript, no Element - conformers add their own
}

// CRITICAL: Protocol extension must have `where Self: ~Copyable`!
extension W2_Indexed where Self: ~Copyable {
    var isEmpty: Bool { startIndex == endIndex }

    var indexCount: Int {
        var count = 0
        var i = startIndex
        while i != endIndex {
            count += 1
            i = index(after: i)
        }
        return count
    }
}

enum W2_Array<Element: ~Copyable>: ~Copyable {
    struct Bounded: ~Copyable {
        var ptr: UnsafeMutablePointer<Element>
        let count: Int
    }
}

extension W2_Array.Bounded: W2_Indexed where Element: ~Copyable {
    typealias Index = Int
    var startIndex: Int { 0 }
    var endIndex: Int { count }
    func index(after i: Int) -> Int { i + 1 }

    // Conformer-provided subscript (not part of protocol)
    subscript(position: Int) -> Element {
        _read { yield ptr[position] }
    }
}

// =============================================================================
// WORKAROUND 4: Protocol for Indexing + Direct Subscript Member + forEach
// =============================================================================

protocol W4_Container: ~Copyable {
    associatedtype Index: Equatable
    var startIndex: Index { get }
    var endIndex: Index { get }
    func index(after i: Index) -> Index
}

// Protocol extension for ~Copyable conformers
extension W4_Container where Self: ~Copyable {
    var isEmpty: Bool { startIndex == endIndex }
}

enum W4_Array<Element: ~Copyable>: ~Copyable {
    struct Bounded: ~Copyable {
        var ptr: UnsafeMutablePointer<Element>
        let count: Int

        // Element access is a direct member, not protocol requirement
        subscript(position: Int) -> Element {
            _read { yield ptr[position] }
        }

        // Borrowing forEach as direct method
        func forEach(_ body: (borrowing Element) -> Void) {
            for i in 0..<count {
                body(ptr[i])
            }
        }
    }
}

extension W4_Array.Bounded: W4_Container where Element: ~Copyable {
    typealias Index = Int
    var startIndex: Int { 0 }
    var endIndex: Int { count }
    func index(after i: Int) -> Int { i + 1 }
}

// =============================================================================
// WORKAROUND 8: Associated Type Defaulted to Never
// =============================================================================
// Alternative: Protocol keeps Element but defaults to Never

protocol W8_Indexed: ~Copyable {
    associatedtype Index: Equatable
    associatedtype Element = Never  // Default to Never

    var startIndex: Index { get }
    var endIndex: Index { get }
    func index(after i: Index) -> Index
}

// Extension for ~Copyable conformers
extension W8_Indexed where Self: ~Copyable {
    var isEmpty: Bool { startIndex == endIndex }
}

// Extension provides default subscript for Never (never called)
extension W8_Indexed where Element == Never {
    subscript(position: Index) -> Element {
        fatalError("No element access for default Element type")
    }
}

enum W8_Array<Elem: ~Copyable>: ~Copyable {
    struct Bounded: ~Copyable {
        var ptr: UnsafeMutablePointer<Elem>
        let count: Int

        // Direct subscript, not part of protocol
        subscript(position: Int) -> Elem {
            _read { yield ptr[position] }
        }
    }
}

// Conform WITHOUT overriding Element - uses default Never
extension W8_Array.Bounded: W8_Indexed where Elem: ~Copyable {
    typealias Index = Int
    // Element stays as Never (default)
    var startIndex: Int { 0 }
    var endIndex: Int { count }
    func index(after i: Int) -> Int { i + 1 }
}

// =============================================================================
// TEST RUNNER
// =============================================================================

func testW2() {
    print("=== WORKAROUND 2: Protocol without Element associatedtype ===")
    let ptr = UnsafeMutablePointer<Token>.allocate(capacity: 2)
    ptr.initialize(to: Token(id: 1))
    (ptr + 1).initialize(to: Token(id: 2))

    let bounded = W2_Array<Token>.Bounded(ptr: ptr, count: 2)

    // Protocol-based operations work:
    print("isEmpty: \(bounded.isEmpty)")
    print("indexCount: \(bounded.indexCount)")
    print("startIndex: \(bounded.startIndex)")
    print("endIndex: \(bounded.endIndex)")

    // Conformer's subscript works:
    print("element[0].id: \(bounded[0].id)")
    print("element[1].id: \(bounded[1].id)")

    print("✅ W2 WORKS FULLY\n")
}

func testW4() {
    print("=== WORKAROUND 4: Protocol + direct subscript member ===")
    let ptr = UnsafeMutablePointer<Token>.allocate(capacity: 2)
    ptr.initialize(to: Token(id: 10))
    (ptr + 1).initialize(to: Token(id: 20))

    let bounded = W4_Array<Token>.Bounded(ptr: ptr, count: 2)

    // Protocol-based operations:
    print("isEmpty: \(bounded.isEmpty)")
    print("startIndex: \(bounded.startIndex)")
    print("endIndex: \(bounded.endIndex)")

    // Direct member subscript:
    print("element[0].id: \(bounded[0].id)")

    // Direct forEach method:
    print("forEach output:", terminator: " ")
    bounded.forEach { token in
        print(token.id, terminator: " ")
    }
    print()

    print("✅ W4 WORKS FULLY\n")
}

func testW8() {
    print("=== WORKAROUND 8: Associated type defaulted to Never ===")
    let ptr = UnsafeMutablePointer<Token>.allocate(capacity: 1)
    ptr.initialize(to: Token(id: 99))

    let bounded = W8_Array<Token>.Bounded(ptr: ptr, count: 1)

    // Protocol-based operations:
    print("isEmpty: \(bounded.isEmpty)")
    print("startIndex: \(bounded.startIndex)")
    print("endIndex: \(bounded.endIndex)")

    // Direct subscript (not protocol's):
    print("element[0].id: \(bounded[0].id)")

    print("✅ W8 WORKS - protocol ignores Element, conformer uses direct access\n")
}

// Main
print(String(repeating: "=", count: 70))
print("TESTING WORKAROUNDS FOR ~Copyable + Protocol Conformance")
print(String(repeating: "=", count: 70))
print()

testW2()
testW4()
testW8()

print(String(repeating: "=", count: 70))
print("SUMMARY")
print(String(repeating: "=", count: 70))
print("""

WORKING WORKAROUNDS (CONFIRMED):

W2/W4: ✅ FULL SOLUTION
  - Protocol defines: Index, startIndex, endIndex, index(after:)
  - Protocol does NOT define: Element associatedtype, subscript
  - Protocol extensions MUST have: `where Self: ~Copyable`
  - Conformer provides: subscript as direct member (not protocol requirement)
  - Result: Full protocol conformance + full element access for ~Copyable

W8: ✅ ALTERNATIVE SOLUTION
  - Protocol defines: associatedtype Element = Never (default)
  - Conformer: Uses default Element=Never, provides direct subscript
  - Result: Protocol conformance (with Never Element) + direct access

KEY INSIGHT:
  The problem is `associatedtype Element` without ~Copyable suppression.
  SOLUTION: Remove it from protocol, conformers add subscript directly.

  Protocol extensions must include `where Self: ~Copyable` to be
  callable on ~Copyable conformers!

RECOMMENDED APPROACH FOR Collection.Indexed:
  1. Remove `associatedtype Element` from Collection.Indexed
  2. Remove `subscript(position:) -> Element` from Collection.Indexed
  3. Keep: Index, startIndex, endIndex, index(after:)
  4. Add `where Self: ~Copyable` to all protocol extensions
  5. Conformers provide subscript as direct member

""")
