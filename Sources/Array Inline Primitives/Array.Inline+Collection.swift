public import Collection_Primitives
public import Index_Primitives
public import Array_Primitives_Core

// MARK: - Collection.Protocol Conformance
// Note: Index, startIndex, endIndex, index(after:) defined in Collection.Indexed conformance

extension Array.Inline: Collection.`Protocol` {}

// MARK: - Collection.Access.Random Conformance
// Note: Collection.Bidirectional conformance is provided below
// for ALL element types (including ~Copyable) via `where Element: ~Copyable`.

extension Array.Inline: Collection.Access.Random {}

// MARK: - Collection.Indexed Conformance

extension Array.Inline: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(_count) }

    @inlinable
    public func index(after i: Index) -> Index { (i + 1)! }
}

// MARK: - Collection.Bidirectional Conformance

extension Array.Inline: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { (i - 1)! }
}

// Note: Array.Inline cannot conform to Swift.Collection because it is unconditionally
// ~Copyable (has deinit for inline storage cleanup). Swift.Collection requires Self: Copyable.
