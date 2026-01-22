public import Collection_Primitives
public import Index_Primitives

// MARK: - Collection.Indexed Conformance

extension Array.Bounded: Collection.Indexed where Element: ~Copyable {
    public typealias Index = Array<Element>.Index

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { Index(_count) }

    @inlinable
    public func index(after i: Index) -> Index { (i + 1)! }
}

// MARK: - Collection.Bidirectional Conformance

extension Array.Bounded: Collection.Bidirectional where Element: ~Copyable {
    @inlinable
    public func index(before i: Index) -> Index { (i - 1)! }
}
