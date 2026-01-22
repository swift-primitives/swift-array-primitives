public import Collection_Primitives

// MARK: - Collection.Indexed Conformance

/// Collection.Indexed conformance for Array.Unbounded.
///
/// This conformance works with ALL element types, including `~Copyable`.
/// Uses index-based access via subscript `_read` for true borrowing semantics.
extension Array.Unbounded: Collection.Indexed {
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { count }

    // subscript(position:) already defined in Array.Unbounded.swift with _read accessor

    @inlinable
    public func index(after i: Int) -> Int { i + 1 }
}

// MARK: - Collection.Indexed_Bidirectional Conformance

extension Array.Unbounded: Collection.Indexed_Bidirectional {
    @inlinable
    public func index(before i: Int) -> Int { i - 1 }
}
