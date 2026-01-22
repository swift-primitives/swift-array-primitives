public import Collection_Primitives

// MARK: - Collection.Indexed Conformance

/// Collection.Indexed conformance for Array.Inline.
///
/// This conformance provides index-based navigation for ALL element types,
/// including `~Copyable` elements.
///
/// ## Design Note: Element Access
///
/// Element access via `subscript(position:)` is provided as a **direct member**
/// of `Array.Inline`, not as a protocol requirement. This is because Swift
/// does not currently support `associatedtype Element: ~Copyable` (deferred from
/// SE-0427), so protocols with `associatedtype Element` implicitly require
/// `Element: Copyable`.
///
/// By keeping the subscript as a direct member, `Array.Inline` maintains full
/// `~Copyable` element support while conforming to the index navigation protocol.
///
/// See: SE-0427 "Noncopyable Generics" Future Directions.
extension Array.Inline: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { 0 }

    @inlinable
    public var endIndex: Int { count }

    @inlinable
    public func index(after i: Int) -> Int { i + 1 }

    // NOTE: subscript(position:) is defined in Array.Inline.swift as a direct
    // member with _read accessor, enabling borrowing access to ~Copyable elements.
}

// MARK: - Collection.Bidirectional Conformance

/// Collection.Bidirectional conformance for Array.Inline.
///
/// Adds backward index traversal capability.
extension Array.Inline: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Int) -> Int { i - 1 }
}
