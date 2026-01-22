public import Collection_Primitives

// MARK: - Collection.Indexed Conformance

/// Collection.Indexed conformance for Array.Bounded.
///
/// This conformance provides index-based navigation for ALL element types,
/// including `~Copyable` elements.
///
/// ## Design Note: Element Access
///
/// Element access via `subscript(position:)` is provided as a **direct member**
/// of `Array.Bounded`, not as a protocol requirement. This is because Swift
/// does not currently support `associatedtype Element: ~Copyable` (deferred from
/// SE-0427), so protocols with `associatedtype Element` implicitly require
/// `Element: Copyable`.
///
/// By keeping the subscript as a direct member, `Array.Bounded` maintains full
/// `~Copyable` element support while conforming to the index navigation protocol.
///
/// See: SE-0427 "Noncopyable Generics" Future Directions.
///
/// ## Usage
///
/// ```swift
/// struct Token: ~Copyable { let id: Int }
///
/// var tokens = try Array<Token>.Bounded(count: 3) { Token(id: $0) }
///
/// // Protocol-based index navigation:
/// print(tokens.isEmpty)       // false
/// print(tokens.startIndex)    // 0
/// print(tokens.endIndex)      // 3
///
/// // Direct subscript access (not protocol requirement):
/// print(tokens[0].id)         // 0
///
/// // Borrowing iteration via direct forEach:
/// tokens.forEach { token in
///     print(token.id)  // borrowing access, not consuming
/// }
/// // tokens still valid
/// ```
extension Array.Bounded: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { count }

    @inlinable
    public func index(after i: Int) -> Int { i + 1 }

    // NOTE: subscript(position:) is defined in Array.Bounded.swift as a direct
    // member with _read accessor, enabling borrowing access to ~Copyable elements.
}

// MARK: - Collection.Bidirectional Conformance

/// Collection.Bidirectional conformance for Array.Bounded.
///
/// Adds backward index traversal capability. Since `Collection.Bidirectional`
/// now inherits from `Collection.Indexed` (not `Collection.Protocol`), this
/// conformance works with ALL element types including `~Copyable`.
extension Array.Bounded: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Int) -> Int { i - 1 }
}
