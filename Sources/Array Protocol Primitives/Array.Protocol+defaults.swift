import Index_Primitives

extension __ArrayProtocol where Self: ~Copyable {

    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing Element) -> R) -> R {
        body(self[index])
    }
}

extension __ArrayProtocol where Self: ~Copyable, Index == Index_Primitives.Index<Element> {

    @inlinable
    public var startIndex: Index { .zero }

    @inlinable
    public var endIndex: Index { count.map(Ordinal.init) }

    @inlinable
    public func index(after i: Index) -> Index { i.successor.saturating() }

    @inlinable
    public func index(before i: Index) -> Index {

        try! i.predecessor.exact()
    }
}
