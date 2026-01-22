// ===----------------------------------------------------------------------===//
// FILE: main.swift (test runner)
// ===----------------------------------------------------------------------===//

struct TestNonCopyable: ~Copyable {
    var value: Int
}

func runTest() {
    let ptr = UnsafeMutablePointer<TestNonCopyable>.allocate(capacity: 1)
    ptr.initialize(to: TestNonCopyable(value: 42))

    let bounded = Array<TestNonCopyable>.Bounded(storage: ptr, count: 1)
    print("Created Array.Bounded with count: \(bounded.count)")
    print("startIndex: \(bounded.startIndex), endIndex: \(bounded.endIndex)")

    print("SUCCESS: Multi-file works WITHOUT Element associated type")
}

runTest()
