public import Collection_Primitives

// MARK: - Collection.Indexed Conformance

/// Collection.Indexed conformance for Array.Bounded.
///
/// This conformance works with ALL element types, including `~Copyable`.
/// Uses index-based access via subscript `_read` for true borrowing semantics.
///
/// ## Usage
///
/// ```swift
/// struct Token: ~Copyable { let id: Int }
///
/// var tokens = try Array<Token>.Bounded(count: 3) { Token(id: $0) }
/// tokens.forEach { token in
///     print(token.id)  // borrowing access, not consuming
/// }
/// // tokens still valid
/// ```
extension Array.Bounded: Collection.Indexed {
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { count }

    // subscript(position:) already defined in Array.Bounded.swift with _read accessor

    @inlinable
    public func index(after i: Int) -> Int { i + 1 }
}

// MARK: - Collection.Indexed_Bidirectional Conformance

extension Array.Bounded: Collection.Indexed_Bidirectional {
    @inlinable
    public func index(before i: Int) -> Int { i - 1 }
}
