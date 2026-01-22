// ===----------------------------------------------------------------------===//
// EXPERIMENT: noncopyable-pointer-propagation-multifile
// FILE: Array.swift (main type declaration)
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Protocol conformance in separate file breaks ~Copyable constraint
//             propagation, causing UnsafeMutablePointer<Element> to fail.
//
// This file mirrors swift-array-primitives/Sources/Array Primitives/Array.swift
//
// ===----------------------------------------------------------------------===//

/// Minimal reproduction of Array namespace with nested Bounded type
public enum Array<Element: ~Copyable>: ~Copyable {

    /// Fixed-capacity array - this has the problematic UnsafeMutablePointer<Element>
    public struct Bounded: ~Copyable {
        @usableFromInline
        var storage: UnsafeMutablePointer<Element>  // <-- This is line 51 in production

        public let count: Int

        public init(storage: UnsafeMutablePointer<Element>, count: Int) {
            self.storage = storage
            self.count = count
        }

        deinit {
            for i in 0..<count {
                (storage + i).deinitialize(count: 1)
            }
            if count > 0 {
                storage.deallocate()
            }
        }
    }
}
