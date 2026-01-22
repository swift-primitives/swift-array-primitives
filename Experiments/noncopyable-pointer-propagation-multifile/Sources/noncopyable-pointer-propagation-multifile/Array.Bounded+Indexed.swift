// ===----------------------------------------------------------------------===//
// FILE: Array.Bounded+Indexed.swift (protocol conformance - SEPARATE FILE)
// ===----------------------------------------------------------------------===//

// VARIANT 1: Conforming to IndexedNoElement (works!)
extension Array.Bounded: IndexedNoElement where Element: ~Copyable {
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { count }

    @inlinable
    public func index(after i: Int) -> Int { i + 1 }
}

// VARIANT 2: Conforming to Indexed WITH Element associated type
// TESTING: Does this FAIL due to implicit 'where Element: Copyable'?
extension Array.Bounded: Indexed where Element: ~Copyable {
    // Index already defined from IndexedNoElement
    // startIndex, endIndex, index(after:) already provided

    public subscript(position: Int) -> Element {
        _read { yield storage[position] }
    }
}
