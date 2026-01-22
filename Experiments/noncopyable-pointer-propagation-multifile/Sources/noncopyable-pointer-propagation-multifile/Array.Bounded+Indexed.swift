// ===----------------------------------------------------------------------===//
// FILE: Array.Bounded+Indexed.swift (protocol conformance - SEPARATE FILE)
// ===----------------------------------------------------------------------===//
//
// Multi-file test: Conformance in separate file from type definition.
// This is the scenario that failed before.
//
// ===----------------------------------------------------------------------===//

extension Array.Bounded: Indexed where Element: ~Copyable {
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { count }

    @inlinable
    public func index(after i: Int) -> Int { i + 1 }

    // Subscript as direct member (not protocol requirement)
    public subscript(position: Int) -> Element {
        _read { yield storage[position] }
    }
}
