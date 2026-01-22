// ===----------------------------------------------------------------------===//
// FILE: main.swift (test runner)
// ===----------------------------------------------------------------------===//
//
// Multi-file test of the workaround:
// - Array.swift: Type definition with UnsafeMutablePointer<Element>
// - Protocol.swift: Protocol WITHOUT associatedtype Element
// - Array.Bounded+Indexed.swift: Conformance in SEPARATE file
//
// ===----------------------------------------------------------------------===//

struct TestNonCopyable: ~Copyable {
    var value: Int
}

func runTest() {
    let ptr = UnsafeMutablePointer<TestNonCopyable>.allocate(capacity: 2)
    ptr.initialize(to: TestNonCopyable(value: 42))
    (ptr + 1).initialize(to: TestNonCopyable(value: 99))

    let bounded = Array<TestNonCopyable>.Bounded(storage: ptr, count: 2)

    print("=== MULTI-FILE TEST ===")
    print("Type: Array<TestNonCopyable>.Bounded")
    print("count: \(bounded.count)")

    // Protocol-based operations (from extension in Protocol.swift):
    print("isEmpty (protocol extension): \(bounded.isEmpty)")
    print("startIndex (protocol requirement): \(bounded.startIndex)")
    print("endIndex (protocol requirement): \(bounded.endIndex)")

    // Direct subscript (from Array.Bounded+Indexed.swift):
    print("element[0].value: \(bounded[0].value)")
    print("element[1].value: \(bounded[1].value)")

    print()
    print("✅ MULTI-FILE WORKAROUND WORKS!")
    print("   - UnsafeMutablePointer<Element> in type definition: OK")
    print("   - Protocol conformance in separate file: OK")
    print("   - ~Copyable element access via subscript: OK")
}

runTest()
