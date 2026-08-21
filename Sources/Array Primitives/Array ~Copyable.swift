public import Array_Primitive
public import Array_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Span_Protocol_Primitives
public import Store_Protocol_Primitives

extension __Array: Collection.`Protocol`
where S: Span.`Protocol` & Store.`Protocol` & Buffer.`Protocol` & ~Copyable {}

extension __Array: Collection.Bidirectional
where S: Span.`Protocol` & Store.`Protocol` & Buffer.`Protocol` & ~Copyable {}

extension __Array: __ArrayProtocol
where S: Span.`Protocol` & Store.`Protocol` & Buffer.`Protocol` & ~Copyable {}

extension __Array where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public var count: Index.Count {
        store.count
    }

    @inlinable
    public var isEmpty: Bool { store.isEmpty }

    @inlinable
    public var capacity: Index.Count { store.capacity }

    @inlinable
    public var freeCapacity: Index.Count {
        store.capacity.subtract.saturating(store.count)
    }
}

extension __Array where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public subscript(_ index: Index) -> S.Element {
        _read {
            precondition(index < count, "Index out of bounds")
            yield store[index]
        }
        _modify {
            precondition(index < count, "Index out of bounds")
            store.unshare()
            yield &store[index]
        }
    }

    @inlinable
    public func withElement<R>(at index: Index, _ body: (borrowing S.Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(store[index])
    }
}

extension __Array
where
    S: ~Copyable,
    S.Element: Copyable,
    S: Store.`Protocol` & Buffer.`Protocol`
{

    @inlinable
    public func element(at index: Index) -> S.Element? {
        guard index < count else { return nil }
        return store[index]
    }

    @inlinable
    public func element(
        at base: Index,
        offsetBy offset: Index.Offset
    ) -> S.Element? {
        let newIndex: Index
        do throws(Ordinal.Error) {
            newIndex = try base + offset
        } catch {
            return nil
        }
        guard newIndex < count else { return nil }
        return store[newIndex]
    }
}

extension __Array where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {

    @inlinable
    public mutating func pop() -> S.Element? {
        if isEmpty { return nil }
        store.unshare()
        let end: Index = count.map(Ordinal.init)

        let last = try! end.predecessor.exact()
        return store.move(at: last)
    }

    @inlinable
    public mutating func remove(at index: Index) -> S.Element {
        precondition(index < count, "Index out of bounds")
        store.unshare()
        return _removeShiftingDown(at: index)
    }

    @inlinable
    package mutating func _removeShiftingDown(at position: Index) -> S.Element {
        var frontier: Index.Count = count.subtract.saturating(.one)
        var carry = store.move(at: frontier.map(Ordinal.init))
        while position < frontier.map(Ordinal.init) {
            frontier = frontier.subtract.saturating(.one)
            let slot: Index = frontier.map(Ordinal.init)
            Swift.swap(&carry, &store[slot])
        }
        return carry
    }

    @inlinable
    public mutating func swap(at i: Index, with j: Index) {
        precondition(i < count && j < count, "Index out of bounds")
        guard i != j else { return }
        store.unshare()
        store.swapAt(i, j)
    }

    @inlinable
    public mutating func drain(_ body: (consuming S.Element) -> Void) {
        store.unshare()

        var low: Index = .zero
        var high: Index.Count = count.subtract.saturating(.one)
        while low < high.map(Ordinal.init) {
            store.swapAt(low, high.map(Ordinal.init))
            low = low.successor.saturating()
            high = high.subtract.saturating(.one)
        }

        while !isEmpty {
            let end: Index = count.map(Ordinal.init)

            let last = try! end.predecessor.exact()
            body(store.move(at: last))
        }
    }
}

extension __Array where S: Copyable, S: Store.`Protocol` {

    @inlinable
    public borrowing func clone() -> Self {
        var result = copy self
        result.store.unshare()
        return result
    }
}
